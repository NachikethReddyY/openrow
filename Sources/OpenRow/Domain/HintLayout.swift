import CoreGraphics

enum HintSide: CaseIterable, Hashable {
    case above, below, left, right
}

struct HintPlacement {
    let rect: CGRect
    let tip: CGPoint
    let side: HintSide

    var base: CGPoint {
        switch side {
        case .above: CGPoint(x: min(max(tip.x, rect.minX + 3), rect.maxX - 3), y: rect.minY)
        case .below: CGPoint(x: min(max(tip.x, rect.minX + 3), rect.maxX - 3), y: rect.maxY)
        case .left: CGPoint(x: rect.maxX, y: min(max(tip.y, rect.minY + 3), rect.maxY - 3))
        case .right: CGPoint(x: rect.minX, y: min(max(tip.y, rect.minY + 3), rect.maxY - 3))
        }
    }
}

enum HintLayout {
    /// Cocoa coordinates. Placement never changes the click point, even at screen edges.
    static func place(at point: CGPoint, size: CGSize, bounds: CGRect, occupied: [CGRect]) -> HintPlacement {
        let gap = max(6, size.height / 2 + 2)
        var best: HintPlacement?
        var bestScore = CGFloat.infinity
        for side in HintSide.allCases {
            let origin: CGPoint = switch side {
            case .above: CGPoint(x: point.x - size.width / 2, y: point.y + gap)
            case .below: CGPoint(x: point.x - size.width / 2, y: point.y - gap - size.height)
            case .left: CGPoint(x: point.x - gap - size.width, y: point.y - size.height / 2)
            case .right: CGPoint(x: point.x + gap, y: point.y - size.height / 2)
            }
            let rect = CGRect(x: min(max(bounds.minX, origin.x), bounds.maxX - size.width),
                y: min(max(bounds.minY, origin.y), bounds.maxY - size.height), width: size.width, height: size.height)
            let overlap = occupied.reduce(CGFloat.zero) { total, other in
                let intersection = rect.insetBy(dx: -1, dy: -1).intersection(other)
                return total + (intersection.isNull ? 0 : intersection.width * intersection.height)
            }
            let displacement = abs(origin.x - rect.minX) + abs(origin.y - rect.minY)
            let score = (rect.contains(point) ? 1_000_000 : 0) + overlap * 100 + displacement
            if score < bestScore {
                bestScore = score
                best = HintPlacement(rect: rect, tip: point, side: side)
            }
        }
        return best!
    }
}
