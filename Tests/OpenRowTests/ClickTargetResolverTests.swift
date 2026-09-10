import XCTest
@testable import OpenRow

final class ClickTargetResolverTests: XCTestCase {
    private func node(_ id: Int, _ parent: Int?, _ role: String, actionable: Bool = true) -> ClickTargetNode {
        ClickTargetNode(id: id, parentID: parent, role: role, actionable: actionable)
    }

    func testOneHintForRowIconAndTextThroughWrappers() {
        let nodes = [node(0, nil, "AXRadioButton"), node(1, 0, "AXGroup"),
                     node(2, 1, "AXImage"), node(3, 1, "AXStaticText"), node(4, 0, "AXStaticText")]
        XCTAssertEqual(ClickTargetResolver.resolve(nodes), [0])
    }

    func testNestedControlsKeepTheirOwnHintsAndOwnTheirLabels() {
        let nodes = [node(0, nil, "AXRow"), node(1, 0, "AXStaticText"),
                     node(2, 0, "AXButton"), node(3, 2, "AXStaticText"),
                     node(4, 0, "AXLink"), node(5, 4, "AXStaticText"),
                     node(6, 0, "AXCheckBox"), node(7, 0, "AXDisclosureTriangle")]
        XCTAssertEqual(ClickTargetResolver.resolve(nodes), [0, 2, 4, 6, 7])
    }

    func testGenericGroupsDeferToDescendantActionsWithoutMergingSiblings() {
        let nodes = [node(0, nil, "AXGroup"), node(1, 0, "AXGroup"),
                     node(2, 1, "AXButton"), node(3, 1, "AXButton"), node(4, 2, "AXStaticText")]
        XCTAssertEqual(ClickTargetResolver.resolve(nodes), [2, 3])
    }

    func testStandalonePressTextAndLeafGroupsRemainReachable() {
        let nodes = [node(0, nil, "AXGroup", actionable: false), node(1, 0, "AXStaticText"),
                     node(2, 0, "AXStaticText"), node(3, 0, "AXGroup")]
        XCTAssertEqual(ClickTargetResolver.resolve(nodes), [1, 2, 3])
    }

    func testIneligibleAncestorDoesNotSwallowVisibleChild() {
        XCTAssertEqual(ClickTargetResolver.resolve([node(0, nil, "AXButton", actionable: false),
            node(1, 0, "AXStaticText")]), [1])
    }

    func testStructuralRolesDoNotBecomeClickTargetsFromGenericPress() {
        for role in ["AXWindow", "AXApplication", "AXToolbar", "AXTabGroup", "AXScrollArea", "AXWebArea", "AXList", "AXTable", "AXOutline"] {
            XCTAssertFalse(TargetPolicy.supportsClick(role: role, actions: ["AXPress"]), role)
        }
        XCTAssertTrue(TargetPolicy.supportsClick(role: "AXGroup", actions: ["AXPress"]))
    }
}
