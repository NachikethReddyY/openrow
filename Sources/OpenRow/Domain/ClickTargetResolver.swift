import Foundation

/// Breadth-first AX metadata; parents always precede their children.
struct ClickTargetNode {
    let id: Int
    let parentID: Int?
    let role: String
    let actionable: Bool
}

enum ClickTargetResolver {
    static func resolve(_ nodes: [ClickTargetNode]) -> Set<Int> {
        var owners: [Int: Int] = [:]
        var candidates = Set<Int>()
        for node in nodes {
            let owner = node.parentID.flatMap { owners[$0] }
            let distinct = TargetPolicy.isDistinctControl(role: node.role)
            if node.actionable, distinct || owner == nil {
                candidates.insert(node.id)
            }
            // Text and artwork inherit the nearest real control, including through wrappers.
            // A nested button/link remains independent and becomes its own label's owner.
            owners[node.id] = node.actionable && distinct ? node.id : owner
        }

        var hasActionBelow = Set<Int>()
        for node in nodes.reversed() {
            let descendant = hasActionBelow.contains(node.id)
            if let parent = node.parentID, descendant || candidates.contains(node.id) {
                hasActionBelow.insert(parent)
            }
            // Generic press wrappers are fallback targets only when no finer action exists.
            if descendant, !TargetPolicy.isDistinctControl(role: node.role) {
                candidates.remove(node.id)
            }
        }
        return candidates
    }
}
