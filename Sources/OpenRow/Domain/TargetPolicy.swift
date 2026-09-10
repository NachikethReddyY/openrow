import CoreGraphics
import Foundation

struct TargetSnapshot: Identifiable, Sendable {
    let id: Int
    let pid: Int32
    let frame: CGRect
    var clickPoint: CGPoint? = nil
    var hintSide: HintSide = .above
    var contentFrame: CGRect? = nil
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

    static func actionPoint(frame: CGRect, screens: [CGRect], excluding: [CGRect] = []) -> CGPoint? {
        guard let visible = actionArea(frame: frame, screens: screens, excluding: excluding) else { return nil }
        return CGPoint(x: visible.midX, y: visible.midY)
    }

    static func actionArea(frame: CGRect, screens: [CGRect], excluding: [CGRect] = []) -> CGRect? {
        var intersections = screens.map { frame.intersection($0) }.filter { !$0.isNull && $0.width >= 2 && $0.height >= 2 }
        for exclusion in excluding {
            intersections = intersections.flatMap { rect -> [CGRect] in
                let cut = rect.intersection(exclusion.insetBy(dx: -1, dy: -1))
                guard !cut.isNull else { return [rect] }
                return [
                    CGRect(x: rect.minX, y: rect.minY, width: cut.minX - rect.minX, height: rect.height),
                    CGRect(x: cut.maxX, y: rect.minY, width: rect.maxX - cut.maxX, height: rect.height),
                    CGRect(x: cut.minX, y: rect.minY, width: cut.width, height: cut.minY - rect.minY),
                    CGRect(x: cut.minX, y: cut.maxY, width: cut.width, height: rect.maxY - cut.maxY),
                ].filter { $0.width >= 2 && $0.height >= 2 }
            }
        }
        return intersections.max(by: { $0.width * $0.height < $1.width * $1.height })
    }
}
