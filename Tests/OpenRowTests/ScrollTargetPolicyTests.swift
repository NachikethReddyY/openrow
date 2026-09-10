import XCTest
@testable import OpenRow

final class ScrollTargetPolicyTests: XCTestCase {
    let sidebar = CGRect(x: 1400, y: 100, width: 260, height: 800)
    func testDetachedDocumentBulletsDoNotCreateScrollRegions() {
        let row = CGRect(x: 437.5, y: 357, width: 576, height: 33.5)
        XCTAssertFalse(ScrollTargetPolicy.isOverflow(role: "AXGroup", insideWeb: true, frame: row,
            children: [.init(role: "AXStaticText", frame: CGRect(x: 413.5, y: 356.5, width: 9, height: 17)),
                       .init(role: "AXStaticText", frame: CGRect(x: 437.5, y: 356.5, width: 510.5, height: 34))]))
        XCTAssertFalse(ScrollTargetPolicy.isOverflow(role: "AXGroup", insideWeb: true, frame: row,
            children: [.init(role: "AXStaticText", frame: CGRect(x: 413.5, y: 357, width: 8, height: 17)),
                       .init(role: "AXStaticText", frame: CGRect(x: 421.5, y: 357, width: 4, height: 17)),
                       .init(role: "AXLink", frame: CGRect(x: 437.5, y: 357, width: 80, height: 17))]))
    }

    func testTabSidebarOverflowIsDetectedOutsideWebContent() {
        XCTAssertTrue(ScrollTargetPolicy.isOverflow(role: "AXTabGroup", insideWeb: false, frame: sidebar,
            children: [.init(role: "AXGroup", frame: CGRect(x: 1400, y: 100, width: 260, height: 1400))]))
        XCTAssertTrue(ScrollTargetPolicy.isOverflow(role: "AXGroup", insideWeb: false, insideTabGroup: true, frame: sidebar,
            children: [.init(role: "AXGroup", frame: CGRect(x: 1400, y: 880, width: 260, height: 40))]))
    }
    func testTextOverhangDoesNotMakeToolbarOrRowScrollable() {
        let overhang = CGRect(x: 1400, y: 100, width: 400, height: 20)
        XCTAssertFalse(ScrollTargetPolicy.isOverflow(role: "AXToolbar", insideWeb: false, frame: sidebar, children: [.init(role: "AXGroup", frame: overhang)]))
        XCTAssertFalse(ScrollTargetPolicy.isOverflow(role: "AXRadioButton", insideWeb: false, frame: sidebar, children: [.init(role: "AXGroup", frame: overhang)]))
        XCTAssertFalse(ScrollTargetPolicy.isOverflow(role: "AXGroup", insideWeb: false,
            frame: CGRect(x: 0, y: 0, width: 200, height: 18), children: [.init(role: "AXGroup", frame: overhang)]))
        XCTAssertFalse(ScrollTargetPolicy.isOverflow(role: "AXGroup", insideWeb: false, frame: sidebar,
            children: [.init(role: "AXGroup", frame: CGRect(x: 1400, y: 100, width: 260, height: 1400))]))
    }
    func testWebOverflowAndNonOverflowBoundaries() {
        XCTAssertTrue(ScrollTargetPolicy.isOverflow(role: "AXGroup", insideWeb: true,
            frame: CGRect(x: 0, y: 0, width: 60, height: 40),
            children: [.init(role: "AXStaticText", frame: CGRect(x: 0, y: 45, width: 50, height: 20))]))
        XCTAssertFalse(ScrollTargetPolicy.isOverflow(role: "AXTabGroup", insideWeb: true, frame: sidebar,
            children: [.init(role: "AXGroup", frame: CGRect(x: 1400, y: 100, width: 1000, height: 800))]))
        XCTAssertTrue(ScrollTargetPolicy.isOverflow(role: "AXGroup", insideWeb: true,
            frame: CGRect(x: 0, y: 0, width: 60, height: 40), children: [.init(role: "AXGroup", frame: CGRect(x: 0, y: 0, width: 60, height: 200))]))
        XCTAssertTrue(ScrollTargetPolicy.isOverflow(role: "AXGroup", insideWeb: true, frame: sidebar,
            children: [.init(role: "AXGroup", frame: CGRect(x: 1400, y: 100, width: 1000, height: 800))]))
        XCTAssertFalse(ScrollTargetPolicy.isOverflow(role: "AXGroup", insideWeb: false, frame: sidebar,
            children: [.init(role: "AXGroup", frame: sidebar.insetBy(dx: 10, dy: 10))]))
    }
}
