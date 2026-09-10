import CoreGraphics

struct ScrollTargetChild {
    let role: String
    let frame: CGRect
}

enum ScrollTargetPolicy {
    static func isOverflow(role: String, insideWeb: Bool, insideTabGroup: Bool = false, frame: CGRect, children: [ScrollTargetChild]) -> Bool {
        guard role == "AXGroup" || (role == "AXTabGroup" && !insideWeb),
              insideWeb || insideTabGroup || role == "AXTabGroup",
              frame.width >= (insideWeb ? 2 : 80), frame.height >= (insideWeb ? 2 : 80) else { return false }
        return children.contains { child in
            let content = child.frame
            // List bullets and numbering can sit entirely outside a document row.
            // Ignore only a side marker alongside the row; text above/below a
            // viewport must still provide evidence of vertical scrolling.
            let besideRow = (content.maxX < frame.minX || content.minX > frame.maxX)
                && content.minY < frame.maxY && content.maxY > frame.minY
            if insideWeb, child.role == "AXStaticText", besideRow { return false }
            let vertical = content.height > frame.height + 2 || content.minY < frame.minY - 2 || content.maxY > frame.maxY + 2
            let horizontal = content.width > frame.width + 2 || content.minX < frame.minX - 2 || content.maxX > frame.maxX + 2
            // Native text often extends horizontally past its container. Tab/sidebar
            // viewports need vertical overflow; web regions also support horizontal overflow.
            return vertical || (insideWeb && horizontal)
        }
    }
}
