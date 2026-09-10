import CoreGraphics

enum ScrollTargetPolicy {
    static func isOverflow(role: String, insideWeb: Bool, insideTabGroup: Bool = false, frame: CGRect, children: [CGRect]) -> Bool {
        guard role == "AXGroup" || (role == "AXTabGroup" && !insideWeb),
              insideWeb || insideTabGroup || role == "AXTabGroup",
              frame.width >= (insideWeb ? 2 : 80), frame.height >= (insideWeb ? 2 : 80) else { return false }
        return children.contains { content in
            let vertical = content.height > frame.height + 2 || content.minY < frame.minY - 2 || content.maxY > frame.maxY + 2
            let horizontal = content.width > frame.width + 2 || content.minX < frame.minX - 2 || content.maxX > frame.maxX + 2
            // Native text often extends horizontally past its container. Tab/sidebar
            // viewports need vertical overflow; web regions also support horizontal overflow.
            return vertical || (insideWeb && horizontal)
        }
    }
}
