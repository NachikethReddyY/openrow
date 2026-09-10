import XCTest
@testable import OpenRow

final class HintLayoutTests: XCTestCase {
    let bounds = CGRect(x: 0, y: 0, width: 300, height: 200)
    let size = CGSize(width: 24, height: 14)

    func testPointerTipIsTheClickPointAndBadgeLeavesItVisible() {
        let point = CGPoint(x: 150, y: 100)
        let hint = HintLayout.place(at: point, size: size, bounds: bounds, occupied: [])
        XCTAssertEqual(hint.tip, point)
        XCTAssertFalse(hint.rect.contains(point))
        XCTAssertTrue(bounds.contains(hint.rect))
        XCTAssertEqual(hint.side, .above)
    }

    func testCanUseEverySideToAvoidOtherLabels() {
        let point = CGPoint(x: 150, y: 100)
        var occupied: [CGRect] = []
        var sides = Set<HintSide>()
        for _ in 0..<4 {
            let hint = HintLayout.place(at: point, size: size, bounds: bounds, occupied: occupied)
            XCTAssertEqual(hint.tip, point)
            XCTAssertFalse(occupied.contains { $0.intersects(hint.rect) })
            sides.insert(hint.side)
            occupied.append(hint.rect)
        }
        XCTAssertEqual(sides, Set(HintSide.allCases))
    }

    func testEdgesAndCornersKeepTextOnScreenAndTipFixed() {
        for x: CGFloat in [1, 150, 299] {
            for y: CGFloat in [1, 100, 199] {
                let point = CGPoint(x: x, y: y)
                let hint = HintLayout.place(at: point, size: size, bounds: bounds, occupied: [])
                XCTAssertTrue(bounds.contains(hint.rect), "\(point): \(hint.rect)")
                XCTAssertEqual(hint.tip, point)
                XCTAssertFalse(hint.rect.contains(point))
            }
        }
    }

    func testActionPointAvoidsIndependentControls() {
        let row = CGRect(x: 0, y: 0, width: 200, height: 40)
        let button = CGRect(x: 75, y: 0, width: 50, height: 40)
        let point = TargetPolicy.actionPoint(frame: row, screens: [bounds], excluding: [button])
        XCTAssertNotNil(point)
        XCTAssertTrue(row.contains(point!))
        XCTAssertFalse(button.contains(point!))
        XCTAssertNil(TargetPolicy.actionPoint(frame: row, screens: [bounds], excluding: [row]))
    }

    func testScreenChoiceMatchesClickPointForSpanningTarget() {
        let screens = [CGRect(x: -100, y: 0, width: 100, height: 100), CGRect(x: 0, y: 0, width: 200, height: 200)]
        let point = TargetPolicy.actionPoint(frame: CGRect(x: -10, y: 20, width: 60, height: 30), screens: screens)
        XCTAssertEqual(point, CGPoint(x: 25, y: 35))
    }
}
