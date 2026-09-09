import CoreGraphics

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
        case .left: CGVector(dx: -amount, dy: 0)
        case .down: CGVector(dx: 0, dy: -amount)
        case .up: CGVector(dx: 0, dy: amount)
        case .right: CGVector(dx: amount, dy: 0)
        }
    }
}

