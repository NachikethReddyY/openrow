import CoreGraphics

enum ScrollPosition {
    static func fraction(current: Double, delta: Double, content: Double, viewport: Double) -> Double? {
        guard [current, delta, content, viewport].allSatisfy(\.isFinite), content > 0, viewport > 0 else { return nil }
        let travel = content - viewport
        return travel > 0 ? min(1, max(0, current - delta / travel)) : 0
    }
}

enum ScreenGeometry {
    static func cocoaPoint(fromQuartz point: CGPoint, primaryScreenMaxY: CGFloat) -> CGPoint {
        CGPoint(x: point.x, y: primaryScreenMaxY - point.y)
    }

    static func cocoaRect(fromQuartz rect: CGRect, primaryScreenMaxY: CGFloat) -> CGRect {
        CGRect(
            x: rect.minX,
            y: primaryScreenMaxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    static func localPoint(
        fromQuartz point: CGPoint,
        inCocoaScreenFrame screenFrame: CGRect,
        primaryScreenMaxY: CGFloat
    ) -> CGPoint {
        let cocoaPoint = cocoaPoint(fromQuartz: point, primaryScreenMaxY: primaryScreenMaxY)
        return CGPoint(x: cocoaPoint.x - screenFrame.minX, y: cocoaPoint.y - screenFrame.minY)
    }
}

extension ScrollDirection {
    func vector(points: CGFloat, dashMultiplier: CGFloat, dashed: Bool) -> CGVector {
        let amount = points * (dashed ? dashMultiplier : 1)
        return switch self {
        case .left: CGVector(dx: amount, dy: 0)
        case .down: CGVector(dx: 0, dy: -amount)
        case .up: CGVector(dx: 0, dy: amount)
        case .right: CGVector(dx: -amount, dy: 0)
        }
    }
}
