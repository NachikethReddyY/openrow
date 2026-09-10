import CoreGraphics
import Foundation

struct TargetSnapshot: Identifiable, Sendable {
    let id: Int
    let pid: Int32
    let frame: CGRect
}

enum TargetPolicy {
    private static let clickRoles: Set<String> = ["AXButton", "AXCheckBox", "AXRadioButton", "AXPopUpButton", "AXMenuButton", "AXLink", "AXTextField", "AXTextArea", "AXComboBox", "AXSlider", "AXIncrementor", "AXDisclosureTriangle", "AXTab", "AXMenuItem"]
    private static let structuralRoles: Set<String> = ["AXApplication", "AXWindow", "AXToolbar", "AXTabGroup", "AXScrollArea", "AXWebArea", "AXList", "AXTable", "AXOutline"]

    static func isDistinctControl(role: String) -> Bool {
        clickRoles.contains(role) || role == "AXRow" || role == "AXCell"
    }

    static func supportsClick(role: String, actions: [String]) -> Bool {
        clickRoles.contains(role) || (!structuralRoles.contains(role) && actions.contains("AXPress"))
    }

    static func isEligible(frame: CGRect, enabled: Bool, hidden: Bool, screens: [CGRect]) -> Bool {
        enabled && !hidden && [frame.origin.x, frame.origin.y, frame.width, frame.height].allSatisfy(\.isFinite)
            && frame.width >= 2 && frame.height >= 2 && actionPoint(frame: frame, screens: screens) != nil
    }

    static func isUnchanged(_ original: CGRect, _ current: CGRect) -> Bool {
        abs(original.minX - current.minX) <= 1 && abs(original.minY - current.minY) <= 1
            && abs(original.width - current.width) <= 1 && abs(original.height - current.height) <= 1
    }

    static func actionPoint(frame: CGRect, screens: [CGRect]) -> CGPoint? {
        let intersections = screens.map { frame.intersection($0) }.filter { !$0.isNull && $0.width >= 2 && $0.height >= 2 }
        guard let visible = intersections.max(by: { $0.width * $0.height < $1.width * $1.height }) else { return nil }
        return CGPoint(x: visible.midX, y: visible.midY)
    }
}
