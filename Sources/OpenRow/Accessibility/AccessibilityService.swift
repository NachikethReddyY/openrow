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
        let window: AXUIElement
        let windowNumber: Int?
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
        let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
        let windowNumber = windows.first {
            guard $0[kCGWindowOwnerPID as String] as? Int32 == pid,
                  $0[kCGWindowLayer as String] as? Int == 0,
                  let bounds = $0[kCGWindowBounds as String] as? NSDictionary,
                  let frame = CGRect(dictionaryRepresentation: bounds), let windowBounds else { return false }
            return TargetPolicy.isUnchanged(windowBounds, frame)
        }?[kCGWindowNumber as String] as? Int
        var queue: [(AXUIElement, CGRect?, Bool, Bool, Int?)] = [(window, windowBounds, false, false, nil)]
        var cursor = 0
        var seen = Set<CFHashCode>()
        var frames = Set<String>()
        var found: [Entry] = []
        var clickNodes: [ClickTargetNode] = []
        while cursor < queue.count, cursor < 5000 {
            try Task.checkCancellation()
            guard start.duration(to: .now) < .seconds(1.5) else { throw DiscoveryError.timedOut }
            let (element, clip, insideWeb, insideTabGroup, parentID) = queue[cursor]
            let nodeID = cursor
            cursor += 1
            guard seen.insert(CFHash(element)).inserted else { continue }
            guard let values = attributes(element), !values.hidden, values.enabled else { continue }
            let frame = values.frame
            let web = insideWeb || values.role == "AXWebArea"
            let tabGroup = insideTabGroup || (!web && values.role == "AXTabGroup")
            let children = children(of: element, limit: max(0, 5000 - queue.count))
            // Browser chrome (including Zen's tab sidebar) can expose overflow groups
            // outside AXWebArea, without dedicated scrollbar attributes.
            let overflow = (values.role == "AXGroup" || values.role == "AXTabGroup") && frame.map { viewport in
                ScrollTargetPolicy.isOverflow(role: values.role, insideWeb: web, insideTabGroup: tabGroup, frame: viewport,
                    children: children.compactMap { attributes($0)?.frame })
            } == true
            let scrollable = scrollRoles.contains(values.role) || overflow
            var childClip = clip
            if scrollable || (!web && values.role == "AXTabGroup"), let frame {
                childClip = clip.map { $0.intersection(frame) } ?? frame
            }
            var actionable = false
            if let frame {
                let visible = clip.map { $0.intersection(frame) } ?? frame
                let supported = mode == .scroll ? scrollable : supportsClick(element, role: values.role)
                if supported, values.subrole != "AXSecureTextField",
                   TargetPolicy.isEligible(frame: visible, enabled: values.enabled, hidden: values.hidden, screens: screens) {
                    let signature = "\(Int(visible.minX.rounded())):\(Int(visible.minY.rounded())):\(Int(visible.width.rounded())):\(Int(visible.height.rounded()))"
                    if mode == .click || frames.insert(signature).inserted {
                        actionable = true
                        let snapshot = TargetSnapshot(id: nodeID, pid: pid, frame: visible)
                        found.append(Entry(element: element, originalFrame: frame, snapshot: snapshot,
                                           window: window, windowNumber: windowNumber))
                    }
                }
            }
            if mode == .click {
                clickNodes.append(ClickTargetNode(id: nodeID, parentID: parentID, role: values.role, actionable: actionable))
            }
            // Bound the returned children as well as traversal so one wide node cannot allocate unbounded work.
            queue.append(contentsOf: children.map { ($0, childClip, web, tabGroup, nodeID) })
            if cursor.isMultiple(of: 24) { await Task.yield() }
        }
        try Task.checkCancellation()
        // An incomplete tree must never look like a complete set of reachable controls.
        if cursor < queue.count || queue.count >= 5000 { throw DiscoveryError.timedOut }
        if mode == .click {
            let resolved = ClickTargetResolver.resolve(clickNodes)
            found.removeAll { !resolved.contains($0.snapshot.id) }
            if found.count > HintAssigner.maximumCount { throw DiscoveryError.tooManyTargets }
            let controls = found
            found = controls.compactMap { entry in
                let frame = entry.snapshot.frame
                let nested = controls.filter {
                    $0.snapshot.id != entry.snapshot.id && frame.contains($0.snapshot.frame)
                        && !TargetPolicy.isUnchanged(frame, $0.snapshot.frame)
                }.map(\.snapshot.frame)
                guard let point = TargetPolicy.actionPoint(frame: frame, screens: screens, excluding: nested) else { return nil }
                var snapshot = entry.snapshot
                snapshot.clickPoint = point
                return Entry(element: entry.element, originalFrame: entry.originalFrame, snapshot: snapshot,
                    window: entry.window, windowNumber: entry.windowNumber)
            }
        }
        entries = Dictionary(uniqueKeysWithValues: found.map { ($0.snapshot.id, $0) })
        if mode == .click {
            var reachable: [Entry] = []
            for entry in found {
                try Task.checkCancellation()
                guard start.duration(to: .now) < .seconds(1.5) else { throw DiscoveryError.timedOut }
                // Browser trees can expose hidden, overlapping controls and empty press
                // wrappers. Keep only targets whose displayed point reaches their owner.
                if let point = entry.snapshot.clickPoint, validatedHit(entry, at: point, isClick: true) != nil {
                    reachable.append(entry)
                }
            }
            found = reachable
            entries = Dictionary(uniqueKeysWithValues: found.map { ($0.snapshot.id, $0) })
        }
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
              let focusedWindow = elementAttribute(AXUIElementCreateApplication(target.pid), kAXFocusedWindowAttribute),
              CFEqual(focusedWindow, entry.window),
              let current = attributes(entry.element), let frame = current.frame,
              current.subrole != "AXSecureTextField",
              TargetPolicy.isUnchanged(entry.originalFrame, frame),
              TargetPolicy.isEligible(frame: frame, enabled: current.enabled, hidden: current.hidden, screens: screens),
              let point = target.clickPoint ?? TargetPolicy.actionPoint(frame: target.frame, screens: screens),
              target.frame.contains(point), screens.contains(where: { $0.contains(point) })
        else { return nil }

        return validatedHit(entry, at: point, isClick: target.clickPoint != nil)
    }

    private func validatedHit(_ entry: Entry, at point: CGPoint, isClick: Bool) -> CGPoint? {
        // Reject an occluding window or another control that has replaced this target.
        var hit: AXUIElement?
        guard AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), Float(point.x), Float(point.y), &hit) == .success,
              var candidate = hit else { return nil }
        let initialHit = candidate
        for _ in 0..<12 {
            if CFEqual(candidate, entry.element) { return point }
            // A row's action must not turn into a newly moved nested button's action.
            if isClick, let hitValues = attributes(candidate),
               TargetPolicy.isDistinctControl(role: hitValues.role), supportsClick(candidate, role: hitValues.role) {
                return nil
            }
            guard let parent = elementAttribute(candidate, kAXParentAttribute) else { break }
            candidate = parent
        }
        // NSViewRepresentable hosts can hit-test to their wrapper instead of the embedded WebKit tree.
        // Descend only through a unique visible child at this point. Ambiguous overlaps fail closed.
        candidate = initialHit
        for _ in 0..<12 {
            var count = 0
            guard AXUIElementGetAttributeValueCount(candidate, kAXChildrenAttribute as CFString, &count) == .success,
                  count <= 128 else { return nil }
            let matching = children(of: candidate, limit: 128).filter {
                guard let values = attributes($0), values.enabled, !values.hidden,
                      let frame = values.frame else { return false }
                return frame.contains(point)
            }
            guard matching.count == 1, let next = matching.first, !CFEqual(next, candidate) else { return nil }
            if CFEqual(next, entry.element) { return point }
            candidate = next
        }
        return nil
    }

    /// Prefer accessible positions; send window-directed wheels when no writable position is exposed.
    func scroll(_ target: TargetSnapshot, vector: CGVector, screens: [CGRect],
                shouldContinue: @escaping @Sendable () -> Bool) async -> Bool {
        guard shouldContinue(), !IsSecureEventInputEnabled(),
              let point = revalidate(target, screens: screens), let entry = entries[target.id] else { return false }
        guard let content = contentSize(entry.element), let viewport = attributes(entry.element)?.frame?.size,
              hasWritableScrollbars(entry.element, vector: vector, content: content, viewport: viewport) else {
            guard let windowNumber = entry.windowNumber,
                  revalidate(target, screens: screens) != nil else { return false }
            return await WindowScrollActions.scroll(pid: target.pid, windowNumber: windowNumber,
                at: point, vector: vector, shouldContinue: shouldContinue)
        }
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

    private func hasWritableScrollbars(_ element: AXUIElement, vector: CGVector, content: CGSize, viewport: CGSize) -> Bool {
        // A same-sized web area without scrollbars may contain nested scrolling beneath the pointer.
        var hasBar = false
        for (name, delta, extent, visible) in [
            (kAXHorizontalScrollBarAttribute, vector.dx, content.width, viewport.width),
            (kAXVerticalScrollBarAttribute, vector.dy, content.height, viewport.height)
        ] where delta != 0 {
            guard let bar = elementAttribute(element, name) else {
                if extent > visible { return false }
                continue
            }
            var settable: DarwinBoolean = false
            guard AXUIElementIsAttributeSettable(bar, kAXValueAttribute as CFString, &settable) == .success,
                  settable.boolValue else { return false }
            hasBar = true
        }
        return hasBar
    }

    private func children(of element: AXUIElement, limit: Int) -> [AXUIElement] {
        guard limit > 0 else { return [] }
        var children: CFArray?
        guard AXUIElementCopyAttributeValues(element, kAXChildrenAttribute as CFString, 0, limit, &children) == .success else { return [] }
        return children as? [AXUIElement] ?? []
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
