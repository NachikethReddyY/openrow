import CoreGraphics
import XCTest
@testable import OpenRow

final class GeometryTests: XCTestCase {
    func testScrollFractionUsesContentTravelAndClampsAtEdges() {
        XCTAssertEqual(ScrollPosition.fraction(current: 0.2, delta: -60, content: 1600, viewport: 400), 0.25)
        XCTAssertEqual(ScrollPosition.fraction(current: 0.99, delta: -60, content: 1600, viewport: 400), 1)
        XCTAssertEqual(ScrollPosition.fraction(current: 0.01, delta: 60, content: 1600, viewport: 400), 0)
        XCTAssertNil(ScrollPosition.fraction(current: 0.5, delta: 10, content: .nan, viewport: 400))
        XCTAssertEqual(ScrollPosition.fraction(current: 0, delta: 10, content: 400, viewport: 400), 0)
    }
    func testQuartzToCocoaConversionUsesPrimaryScreenHeight() {
        let quartz = CGPoint(x: 300, y: 140)

        let cocoa = ScreenGeometry.cocoaPoint(fromQuartz: quartz, primaryScreenMaxY: 900)

        XCTAssertEqual(cocoa, CGPoint(x: 300, y: 760))
    }

    func testLocalPointSupportsNegativeOriginDisplays() {
        let quartz = CGPoint(x: -900, y: 300)
        let screenFrame = CGRect(x: -1280, y: 100, width: 1280, height: 800)

        let local = ScreenGeometry.localPoint(
            fromQuartz: quartz,
            inCocoaScreenFrame: screenFrame,
            primaryScreenMaxY: 900
        )

        XCTAssertEqual(local, CGPoint(x: 380, y: 500))
    }

    func testScrollVectorsFollowVimDirections() {
        XCTAssertEqual(ScrollDirection.left.vector(points: 8, dashMultiplier: 4, dashed: false), CGVector(dx: 8, dy: 0))
        XCTAssertEqual(ScrollDirection.down.vector(points: 8, dashMultiplier: 4, dashed: false), CGVector(dx: 0, dy: -8))
        XCTAssertEqual(ScrollDirection.up.vector(points: 8, dashMultiplier: 4, dashed: true), CGVector(dx: 0, dy: 32))
        XCTAssertEqual(ScrollDirection.right.vector(points: 8, dashMultiplier: 4, dashed: true), CGVector(dx: -32, dy: 0))
    }
}
