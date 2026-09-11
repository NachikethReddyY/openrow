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
    /// Center the Mission Control badge across the top border, clamped to its display.
    static func borderBadge(in card: CGRect, size: CGSize, bounds: CGRect) -> CGRect {
        CGRect(x: min(max(bounds.minX, card.midX - size.width / 2), bounds.maxX - size.width),
            y: min(max(bounds.minY, card.maxY - size.height / 2), bounds.maxY - size.height),
            width: size.width, height: size.height)
    }

    /// Cocoa coordinates. Placement never changes the click point, even at screen edges.
    static func place(at point: CGPoint, size: CGSize, bounds: CGRect, occupied: [CGRect],
                      components: [CGRect] = [], preferredSide: HintSide = .above) -> HintPlacement {
        var best: HintPlacement?
        var bestScore = CGFloat.infinity
        for side in [preferredSide] + HintSide.allCases.filter({ $0 != preferredSide }) {
            let placement = candidate(at: point, side: side, size: size, bounds: bounds)
            let score = score(placement, occupied: occupied, components: components)
            if score < bestScore {
                bestScore = score
                best = placement
            }
        }
        return best!
    }

    /// Pick a short-tail anchor just inside a safe area, with its label outside the control.
    static func anchor(in area: CGRect, size: CGSize, bounds: CGRect, components: [CGRect]) -> HintPlacement {
        HintSide.allCases.map { side in
            let point: CGPoint = switch side {
            case .above: CGPoint(x: area.midX, y: area.maxY - min(2, area.height / 2))
            case .below: CGPoint(x: area.midX, y: area.minY + min(2, area.height / 2))
            case .left: CGPoint(x: area.minX + min(2, area.width / 2), y: area.midY)
            case .right: CGPoint(x: area.maxX - min(2, area.width / 2), y: area.midY)
            }
            return candidate(at: point, side: side, size: size, bounds: bounds)
        }.min { score($0, occupied: [], components: components) < score($1, occupied: [], components: components) }!
    }

    private static func candidate(at point: CGPoint, side: HintSide, size: CGSize, bounds: CGRect) -> HintPlacement {
        let gap: CGFloat = 3
        let origin: CGPoint = switch side {
            case .above: CGPoint(x: point.x - size.width / 2, y: point.y + gap)
            case .below: CGPoint(x: point.x - size.width / 2, y: point.y - gap - size.height)
            case .left: CGPoint(x: point.x - gap - size.width, y: point.y - size.height / 2)
            case .right: CGPoint(x: point.x + gap, y: point.y - size.height / 2)
        }
        let rect = CGRect(x: min(max(bounds.minX, origin.x), bounds.maxX - size.width),
            y: min(max(bounds.minY, origin.y), bounds.maxY - size.height), width: size.width, height: size.height)
        return HintPlacement(rect: rect, tip: point, side: side)
    }

    private static func score(_ placement: HintPlacement, occupied: [CGRect], components: [CGRect]) -> CGFloat {
        func overlap(_ others: [CGRect]) -> CGFloat {
            others.reduce(0) { total, other in
                let intersection = placement.rect.insetBy(dx: -0.5, dy: -0.5).intersection(other)
                return total + (intersection.isNull ? 0 : intersection.width * intersection.height)
            }
        }
        let distance = hypot(placement.base.x - placement.tip.x, placement.base.y - placement.tip.y)
        return (placement.rect.contains(placement.tip) ? 1_000_000 : 0)
            + overlap(occupied) * 100 + overlap(components) * 10 + distance
    }
}
