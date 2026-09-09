import XCTest
@testable import OpenRow

final class TargetPolicyTests: XCTestCase {
    let screens = [CGRect(x: 0, y: 0, width: 1440, height: 900)]

    func testRejectsUnsafeGeometryAndState() {
        XCTAssertFalse(TargetPolicy.isEligible(frame: CGRect(x: CGFloat.nan, y: 0, width: 10, height: 10), enabled: true, hidden: false, screens: screens))
        XCTAssertFalse(TargetPolicy.isEligible(frame: CGRect(x: 1500, y: 0, width: 10, height: 10), enabled: true, hidden: false, screens: screens))
        XCTAssertFalse(TargetPolicy.isEligible(frame: CGRect(x: 0, y: 0, width: 10, height: 10), enabled: false, hidden: false, screens: screens))
        XCTAssertFalse(TargetPolicy.isEligible(frame: CGRect(x: 0, y: 0, width: 10, height: 10), enabled: true, hidden: true, screens: screens))
        XCTAssertTrue(TargetPolicy.isEligible(frame: CGRect(x: -10, y: 10, width: 30, height: 30), enabled: true, hidden: false, screens: screens))
    }

    func testMovedTargetIsRejectedAndClickIsInsideVisibleIntersection() {
        let old = CGRect(x: -10, y: 10, width: 30, height: 30)
        XCTAssertTrue(TargetPolicy.isUnchanged(old, old.offsetBy(dx: 0.5, dy: 0)))
        XCTAssertFalse(TargetPolicy.isUnchanged(old, old.offsetBy(dx: 20, dy: 0)))
        XCTAssertEqual(TargetPolicy.actionPoint(frame: old, screens: screens), CGPoint(x: 10, y: 25))
    }
}
