import Foundation
import CoreGraphics

/// Breadth-first AX metadata; parents always precede their children.
struct ClickTargetNode {
    let id: Int
    let parentID: Int?
    let role: String
    let actionable: Bool
}

enum ClickTargetResolver {
    /// Reuse the discovered tree: no extra AX reads or UI text leaves the service.
    static func contentFrames(_ nodes: [ClickTargetNode], targets: Set<Int>, frames: [Int: CGRect]) -> [Int: CGRect] {
        var owners: [Int: Int] = [:]
        var result: [Int: CGRect] = [:]
        for node in nodes {
            let owner = targets.contains(node.id) ? node.id : node.parentID.flatMap { owners[$0] }
            owners[node.id] = owner
            guard let owner, owner != node.id, node.role == "AXImage" || node.role == "AXStaticText",
                  let frame = frames[node.id], !frame.isNull, frame.width >= 2, frame.height >= 2 else { continue }
            result[owner] = result[owner].map { $0.union(frame) } ?? frame
        }
        return result
    }

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
