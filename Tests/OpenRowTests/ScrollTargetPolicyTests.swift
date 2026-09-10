import XCTest
@testable import OpenRow

final class ScrollTargetPolicyTests: XCTestCase {
    let sidebar = CGRect(x: 1400, y: 100, width: 260, height: 800)
    func testTabSidebarOverflowIsDetectedOutsideWebContent() {
        XCTAssertTrue(ScrollTargetPolicy.isOverflow(role: "AXTabGroup", insideWeb: false, frame: sidebar,
            children: [CGRect(x: 1400, y: 100, width: 260, height: 1400)]))
        XCTAssertTrue(ScrollTargetPolicy.isOverflow(role: "AXGroup", insideWeb: false, insideTabGroup: true, frame: sidebar,
            children: [CGRect(x: 1400, y: 880, width: 260, height: 40)]))
    }
    func testTextOverhangDoesNotMakeToolbarOrRowScrollable() {
        let overhang = CGRect(x: 1400, y: 100, width: 400, height: 20)
        XCTAssertFalse(ScrollTargetPolicy.isOverflow(role: "AXToolbar", insideWeb: false, frame: sidebar, children: [overhang]))
        XCTAssertFalse(ScrollTargetPolicy.isOverflow(role: "AXRadioButton", insideWeb: false, frame: sidebar, children: [overhang]))
        XCTAssertFalse(ScrollTargetPolicy.isOverflow(role: "AXGroup", insideWeb: false,
            frame: CGRect(x: 0, y: 0, width: 200, height: 18), children: [overhang]))
        XCTAssertFalse(ScrollTargetPolicy.isOverflow(role: "AXGroup", insideWeb: false, frame: sidebar,
            children: [CGRect(x: 1400, y: 100, width: 260, height: 1400)]))
    }
    func testWebOverflowAndNonOverflowBoundaries() {
        XCTAssertFalse(ScrollTargetPolicy.isOverflow(role: "AXTabGroup", insideWeb: true, frame: sidebar,
            children: [CGRect(x: 1400, y: 100, width: 1000, height: 800)]))
        XCTAssertTrue(ScrollTargetPolicy.isOverflow(role: "AXGroup", insideWeb: true,
            frame: CGRect(x: 0, y: 0, width: 60, height: 40), children: [CGRect(x: 0, y: 0, width: 60, height: 200)]))
        XCTAssertTrue(ScrollTargetPolicy.isOverflow(role: "AXGroup", insideWeb: true, frame: sidebar,
            children: [CGRect(x: 1400, y: 100, width: 1000, height: 800)]))
        XCTAssertFalse(ScrollTargetPolicy.isOverflow(role: "AXGroup", insideWeb: false, frame: sidebar,
            children: [sidebar.insetBy(dx: 10, dy: 10)]))
    }
}
