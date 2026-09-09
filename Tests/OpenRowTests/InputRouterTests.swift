import XCTest
@testable import OpenRow

final class InputRouterTests: XCTestCase {
    private let click = KeyboardShortcut(keyCode: KeyCode.j, modifiers: .hyper)
    private let scroll = KeyboardShortcut(keyCode: KeyCode.k, modifiers: .hyper)

    func testIdlePassesOrdinaryKeysThrough() {
        var router = InputRouter(clickShortcut: click, scrollShortcut: scroll)

        let decision = router.route(.keyDown(KeyCode.a, modifiers: []))

        XCTAssertFalse(decision.shouldConsume)
        XCTAssertNil(decision.command)
    }

    func testActivationChordIsConsumedOnDownAndUp() {
        var router = InputRouter(clickShortcut: click, scrollShortcut: scroll)

        XCTAssertEqual(
            router.route(.keyDown(KeyCode.j, modifiers: .hyper)),
            RouteDecision(consuming: .activateClick)
        )
        XCTAssertEqual(
            router.route(.keyUp(KeyCode.j, modifiers: .hyper)),
            .consumeOnly
        )
    }

    func testClickModeConsumesOnlyItsAllowList() {
        var router = InputRouter(clickShortcut: click, scrollShortcut: scroll)
        router.mode = .click

        XCTAssertEqual(router.route(.keyDown(KeyCode.a)), RouteDecision(consuming: .appendHint(.a)))
        XCTAssertEqual(router.route(.keyDown(KeyCode.delete)), RouteDecision(consuming: .deleteHint))
        XCTAssertEqual(router.route(.keyDown(KeyCode.escape)), RouteDecision(consuming: .cancel))
        XCTAssertEqual(router.route(.keyUp(KeyCode.a)), .consumeOnly)
        XCTAssertEqual(router.route(.keyDown(6)), .passThrough)
    }

    func testClickModeConsumesButIgnoresAutoRepeat() {
        var router = InputRouter(clickShortcut: click, scrollShortcut: scroll)
        router.mode = .click

        XCTAssertEqual(router.route(.keyDown(KeyCode.a, isRepeat: true)), .consumeOnly)
    }

    func testScrollModeRoutesMotionKeyDownAndKeyUp() {
        var router = InputRouter(clickShortcut: click, scrollShortcut: scroll)
        router.mode = .scroll

        XCTAssertEqual(
            router.route(.keyDown(KeyCode.h, modifiers: .shift)),
            RouteDecision(consuming: .setScroll(.left, pressed: true, dash: true))
        )
        XCTAssertEqual(
            router.route(.keyUp(KeyCode.h, modifiers: .shift)),
            RouteDecision(consuming: .setScroll(.left, pressed: false, dash: true))
        )
        XCTAssertEqual(router.route(.keyDown(KeyCode.tab)), RouteDecision(consuming: .cycleRegion))
        XCTAssertEqual(router.route(.keyDown(KeyCode.number3)), RouteDecision(consuming: .selectRegion(2)))
        XCTAssertEqual(router.route(.keyDown(6)), .passThrough)
    }

    func testTapFailureSynchronouslyReturnsRouterToIdleAndPassesThrough() {
        var router = InputRouter(clickShortcut: click, scrollShortcut: scroll)
        router.mode = .click

        let decision = router.route(.tapDisabled)

        XCTAssertEqual(router.mode, .idle)
        XCTAssertEqual(decision, RouteDecision(passingThrough: .tapFailed))
    }

    func testActivationCanSwitchModes() {
        var router = InputRouter(clickShortcut: click, scrollShortcut: scroll)
        router.mode = .click

        XCTAssertEqual(
            router.route(.keyDown(KeyCode.k, modifiers: .hyper)),
            RouteDecision(consuming: .activateScroll)
        )
    }
}

