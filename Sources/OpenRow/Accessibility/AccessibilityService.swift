import ApplicationServices
import Carbon
import Foundation
import OSLog

enum DiscoveryError: LocalizedError {
    case unavailable, secureInput, tooManyTargets, timedOut
    var errorDescription: String? {
        switch self {
        case .unavailable: "This app did not expose an accessible window."
        case .secureInput: "OpenRow is unavailable in secure input fields."
        case .tooManyTargets: "More than 729 controls are visible. Use a smaller window and try again."
        case .timedOut: "This app took too long to expose its controls. Try again."
        }
    }
}

/// All AX handles and IPC stay on this actor. The UI receives geometry and IDs only.
actor AccessibilityService {
    private struct Entry {
        let element: AXUIElement
        let originalFrame: CGRect
        let snapshot: TargetSnapshot
    }
    private struct Attributes {
        let role: String
        let subrole: String
        let frame: CGRect?
        let enabled: Bool
        let hidden: Bool
    }
    private var entries: [Int: Entry] = [:]
    private let logger = Logger(subsystem: "dev.openrow.OpenRow", category: "Discovery")
    private let scrollRoles: Set<String> = ["AXScrollArea", "AXWebArea"]

    func discover(pid: Int32, mode: OpenRowMode, screens: [CGRect]) async throws -> [TargetSnapshot] {
        entries.removeAll(keepingCapacity: true)
        let start = ContinuousClock.now
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.08)
        guard !isSecure(app) else { throw DiscoveryError.secureInput }
        guard let window = elementAttribute(app, kAXFocusedWindowAttribute) ?? elementAttribute(app, kAXMainWindowAttribute) else {
            throw DiscoveryError.unavailable
        }
        let windowBounds = attributes(window)?.frame
        var queue: [(AXUIElement, CGRect?)] = [(window, windowBounds)]
        var cursor = 0
        var seen = Set<CFHashCode>()
        var frames = Set<String>()
        var found: [Entry] = []
        while cursor < queue.count, cursor < 5000 {
            try Task.checkCancellation()
            guard start.duration(to: .now) < .seconds(1.5) else { throw DiscoveryError.timedOut }
            let (element, clip) = queue[cursor]
            cursor += 1
            guard seen.insert(CFHash(element)).inserted else { continue }
            guard let values = attributes(element), !values.hidden, values.enabled else { continue }
            let frame = values.frame
            var childClip = clip
            if scrollRoles.contains(values.role), let frame {
                childClip = clip.map { $0.intersection(frame) } ?? frame
            }
            if let frame {
                let visible = clip.map { $0.intersection(frame) } ?? frame
                let supported = mode == .scroll ? scrollRoles.contains(values.role) : supportsClick(element, role: values.role)
                if supported, values.subrole != "AXSecureTextField",
                   TargetPolicy.isEligible(frame: visible, enabled: values.enabled, hidden: values.hidden, screens: screens) {
                    let signature = "\(Int(visible.minX.rounded())):\(Int(visible.minY.rounded())):\(Int(visible.width.rounded())):\(Int(visible.height.rounded()))"
                    if frames.insert(signature).inserted {
                        let snapshot = TargetSnapshot(id: found.count, pid: pid, frame: visible)
                        found.append(Entry(element: element, originalFrame: frame, snapshot: snapshot))
                        if mode == .click, found.count > HintAssigner.maximumCount { throw DiscoveryError.tooManyTargets }
                    }
                }
            }
            // Bound the returned children as well as traversal so one wide node cannot allocate unbounded work.
            let remaining = 5000 - queue.count
            if remaining > 0 {
                var children: CFArray?
                if AXUIElementCopyAttributeValues(element, kAXChildrenAttribute as CFString, 0, remaining, &children) == .success,
                   let children = children as? [AXUIElement] {
                    queue.append(contentsOf: children.map { ($0, childClip) })
                }
            }
            if cursor.isMultiple(of: 24) { await Task.yield() }
        }
        try Task.checkCancellation()
        // An incomplete tree must never look like a complete set of reachable controls.
        if cursor < queue.count || queue.count >= 5000 { throw DiscoveryError.timedOut }
        entries = Dictionary(uniqueKeysWithValues: found.map { ($0.snapshot.id, $0) })
        let ordered = found.map(\.snapshot).sorted { lhs, rhs in
            let leftScreen = screens.firstIndex(where: { $0.intersects(lhs.frame) }) ?? 0
            let rightScreen = screens.firstIndex(where: { $0.intersects(rhs.frame) }) ?? 0
            if leftScreen != rightScreen { return leftScreen < rightScreen }
            if lhs.frame.minY != rhs.frame.minY { return lhs.frame.minY < rhs.frame.minY }
            if lhs.frame.minX != rhs.frame.minX { return lhs.frame.minX < rhs.frame.minX }
            return lhs.id < rhs.id
        }
        let elapsed = start.duration(to: .now)
        logger.info("Discovery nodes=\(cursor) targets=\(ordered.count) duration=\(String(describing: elapsed), privacy: .public)")
        return ordered
    }

    func revalidate(_ target: TargetSnapshot, screens: [CGRect]) -> CGPoint? {
        guard !Task.isCancelled, let entry = entries[target.id], entry.snapshot.pid == target.pid,
              !isSecure(AXUIElementCreateApplication(target.pid)),
              let current = attributes(entry.element), let frame = current.frame,
              current.subrole != "AXSecureTextField",
              TargetPolicy.isUnchanged(entry.originalFrame, frame),
              TargetPolicy.isEligible(frame: frame, enabled: current.enabled, hidden: current.hidden, screens: screens),
              let point = TargetPolicy.actionPoint(frame: target.frame, screens: screens)
        else { return nil }

        // Reject an occluding window or another control that has replaced this target.
        var hit: AXUIElement?
        guard AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), Float(point.x), Float(point.y), &hit) == .success,
              var candidate = hit else { return nil }
        for _ in 0..<12 {
            if CFEqual(candidate, entry.element) { return point }
            guard let parent = elementAttribute(candidate, kAXParentAttribute) else { break }
            candidate = parent
        }
        return nil
    }

    /// Scroll through exposed scrollbar positions so the hardware pointer never changes.
    func scroll(_ target: TargetSnapshot, vector: CGVector, screens: [CGRect],
                shouldContinue: @Sendable () -> Bool) -> Bool {
        guard shouldContinue(), !IsSecureEventInputEnabled(),
              revalidate(target, screens: screens) != nil, let entry = entries[target.id],
              let content = contentSize(entry.element), let viewport = attributes(entry.element)?.frame?.size else { return false }
        for (name, delta, extent, visible) in [
            (kAXHorizontalScrollBarAttribute, vector.dx, content.width, viewport.width),
            (kAXVerticalScrollBarAttribute, vector.dy, content.height, viewport.height)
        ] where delta != 0 {
            guard shouldContinue(), !IsSecureEventInputEnabled(),
                  let focused = elementAttribute(AXUIElementCreateSystemWide(), kAXFocusedApplicationAttribute) else { return false }
            var focusedPID: pid_t = 0
            guard AXUIElementGetPid(focused, &focusedPID) == .success, focusedPID == target.pid else { return false }
            if extent <= visible { continue }
            guard let bar = elementAttribute(entry.element, name) else { return false }
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(bar, kAXValueAttribute as CFString, &value) == .success,
                  let current = value as? Double,
                  let next = ScrollPosition.fraction(current: current, delta: delta, content: extent, viewport: visible) else { return false }
            if next != current {
                // Recheck after the value/geometry IPC, immediately before the only mutation.
                guard let currentBar = elementAttribute(entry.element, name), CFEqual(currentBar, bar),
                      revalidate(target, screens: screens) != nil,
                      let currentApp = elementAttribute(AXUIElementCreateSystemWide(), kAXFocusedApplicationAttribute),
                      AXUIElementGetPid(currentApp, &focusedPID) == .success, focusedPID == target.pid,
                      shouldContinue(), !IsSecureEventInputEnabled() else { return false }
                if AXUIElementSetAttributeValue(bar, kAXValueAttribute as CFString, NSNumber(value: next)) != .success { return false }
            }
        }
        return true
    }

    private func contentSize(_ element: AXUIElement) -> CGSize? {
        var raw: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, "AXContentSize" as CFString, &raw) == .success,
           let raw, CFGetTypeID(raw) == AXValueGetTypeID() {
            var size = CGSize.zero
            if AXValueGetValue(raw as! AXValue, .cgSize, &size) { return size }
        }
        // AppKit and WebKit also expose content elements with their full, unclipped dimensions.
        var contents: CFArray?
        guard AXUIElementCopyAttributeValues(element, kAXContentsAttribute as CFString, 0, 32, &contents) == .success,
              let elements = contents as? [AXUIElement] else { return nil }
        let frames = elements.compactMap { attributes($0)?.frame }
        guard let first = frames.first else { return nil }
        return frames.dropFirst().reduce(first) { $0.union($1) }.size
    }

    private func isSecure(_ app: AXUIElement) -> Bool {
        guard let focused = elementAttribute(app, kAXFocusedUIElementAttribute) else { return false }
        return attributes(focused)?.subrole == "AXSecureTextField"
    }

    private func supportsClick(_ element: AXUIElement, role: String) -> Bool {
        if TargetPolicy.supportsClick(role: role, actions: []) { return true }
        var actions: CFArray?
        guard AXUIElementCopyActionNames(element, &actions) == .success else { return false }
        return TargetPolicy.supportsClick(role: role, actions: actions as? [String] ?? [])
    }

    private func elementAttribute(_ element: AXUIElement, _ name: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private func attributes(_ element: AXUIElement) -> Attributes? {
        let names = [kAXRoleAttribute, kAXSubroleAttribute, kAXPositionAttribute, kAXSizeAttribute, kAXEnabledAttribute, "AXHidden"] as CFArray
        var result: CFArray?
        guard AXUIElementCopyMultipleAttributeValues(element, names, [], &result) == .success,
              let values = result as? [Any], values.count == 6,
              let role = values[0] as? String else { return nil }
        var frame: CGRect?
        if CFGetTypeID(values[2] as CFTypeRef) == AXValueGetTypeID(),
           CFGetTypeID(values[3] as CFTypeRef) == AXValueGetTypeID() {
            let position = values[2] as! AXValue
            let size = values[3] as! AXValue
            var point = CGPoint.zero
            var extent = CGSize.zero
            if AXValueGetValue(position, .cgPoint, &point), AXValueGetValue(size, .cgSize, &extent) {
                frame = CGRect(origin: point, size: extent)
            }
        }
        return Attributes(role: role, subrole: values[1] as? String ?? "", frame: frame,
            enabled: values[4] as? Bool ?? true, hidden: values[5] as? Bool ?? false)
    }
}
