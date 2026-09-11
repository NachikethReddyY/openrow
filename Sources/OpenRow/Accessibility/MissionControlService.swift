import ApplicationServices
import Carbon
import Foundation

/// Dock owns Mission Control's thumbnails, even while another app remains frontmost.
actor MissionControlService {
    struct Snapshot: Sendable {
        let active: Bool
        let targets: [TargetSnapshot]
    }
    private var entries: [Int: AXUIElement] = [:]
    private var nextID = 0

    func snapshot(pid: Int32, screens: [CGRect]) -> Snapshot {
        let previous = entries
        entries.removeAll(keepingCapacity: true)
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.08)
        guard let root = children(app).first(where: { string($0, "AXIdentifier") == "mc" }) else {
            return Snapshot(active: false, targets: [])
        }
        var queue = [(root, false)]
        var cursor = 0
        var targets: [TargetSnapshot] = []
        let start = ContinuousClock.now
        while cursor < queue.count, cursor < 1500, !Task.isCancelled {
            guard start.duration(to: .now) < .milliseconds(500) else {
                entries.removeAll()
                return Snapshot(active: true, targets: [])
            }
            let (element, inWindows) = queue[cursor]
            cursor += 1
            let identifier = string(element, "AXIdentifier")
            let windows = inWindows || identifier == "mc.windows"
            if windows, string(element, kAXRoleAttribute) == "AXButton", supportsPress(element),
               let frame = frame(element),
               TargetPolicy.isEligible(frame: frame, enabled: value(element, kAXEnabledAttribute) as? Bool ?? true,
                   hidden: value(element, "AXHidden") as? Bool ?? false, screens: screens),
               let point = TargetPolicy.actionPoint(frame: frame, screens: screens) {
                nextID += 1
                let id = previous.first(where: { CFEqual($0.value, element) })?.key ?? nextID
                entries[id] = element
                targets.append(TargetSnapshot(id: id, pid: pid, frame: frame, clickPoint: point))
                continue
            }
            queue.append(contentsOf: children(element).prefix(max(0, 1500 - queue.count)).map { ($0, windows) })
        }
        guard cursor == queue.count, !Task.isCancelled, targets.count <= HintAssigner.maximumCount else {
            entries.removeAll()
            return Snapshot(active: true, targets: [])
        }
        targets.sort { $0.frame.minY == $1.frame.minY ? $0.frame.minX < $1.frame.minX : $0.frame.minY < $1.frame.minY }
        return Snapshot(active: true, targets: targets)
    }

    /// Press the original AX card only while it still belongs to the live Mission Control tree.
    func select(_ target: TargetSnapshot, screens: [CGRect]) -> Bool {
        guard !Task.isCancelled, !IsSecureEventInputEnabled(), let original = entries[target.id] else { return false }
        let current = snapshot(pid: target.pid, screens: screens)
        guard current.active, current.targets.contains(where: {
            guard let element = entries[$0.id] else { return false }
            return CFEqual(element, original) && TargetPolicy.isUnchanged($0.frame, target.frame)
        }), supportsPress(original), !Task.isCancelled, !IsSecureEventInputEnabled() else { return false }
        return AXUIElementPerformAction(original, kAXPressAction as CFString) == .success
    }

    private func value(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, key as CFString, &result) == .success else { return nil }
        return result
    }
    private func string(_ element: AXUIElement, _ key: String) -> String? { value(element, key) as? String }
    private func children(_ element: AXUIElement) -> [AXUIElement] {
        var result: CFArray?
        var count = 0
        guard AXUIElementGetAttributeValueCount(element, kAXChildrenAttribute as CFString, &count) == .success,
              AXUIElementCopyAttributeValues(element, kAXChildrenAttribute as CFString, 0, min(count, 1500), &result) == .success else { return [] }
        return result as? [AXUIElement] ?? []
    }
    private func supportsPress(_ element: AXUIElement) -> Bool {
        var names: CFArray?
        return AXUIElementCopyActionNames(element, &names) == .success && (names as? [String] ?? []).contains(kAXPressAction)
    }
    private func frame(_ element: AXUIElement) -> CGRect? {
        guard let position = value(element, kAXPositionAttribute), CFGetTypeID(position) == AXValueGetTypeID(),
              let size = value(element, kAXSizeAttribute), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        var dimensions = CGSize.zero
        guard AXValueGetValue(position as! AXValue, .cgPoint, &point),
              AXValueGetValue(size as! AXValue, .cgSize, &dimensions) else { return nil }
        return CGRect(origin: point, size: dimensions)
    }
}
