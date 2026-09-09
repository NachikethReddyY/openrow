import XCTest
@testable import OpenRow

final class InputSessionTests: XCTestCase {
    func testFailureCannotBeUndoneByQueuedConfiguration() {
        var session = InputSession(preferences: UserPreferences())
        session.resetFailure()
        session.configure(mode: .click, enabled: true)
        let epoch = session.epoch
        XCTAssertEqual(session.route(.tapDisabled), RouteDecision(passingThrough: .tapFailed))
        XCTAssertNotEqual(session.epoch, epoch)
        session.configure(mode: .scroll, enabled: true)
        XCTAssertEqual(session.route(.keyDown(.j)), .passThrough)
        XCTAssertTrue(session.failed)
    }

    func testOwnedKeyUpIsConsumedAfterCancellationAndModifierRelease() {
        var session = InputSession(preferences: UserPreferences())
        session.configure(mode: .idle, enabled: true)
        XCTAssertTrue(session.route(.keyDown(.j, modifiers: .hyper)).shouldConsume)
        session.configure(mode: .click, enabled: true)
        XCTAssertEqual(session.route(.keyUp(.j)), .consumeOnly)
        XCTAssertTrue(session.route(.keyDown(.a)).shouldConsume)
        session.configure(mode: .idle, enabled: true)
        XCTAssertEqual(session.route(.keyUp(.a)), .consumeOnly)
    }

    func testUnownedKeyUpPassesThroughInActiveMode() {
        var session = InputSession(preferences: UserPreferences())
        session.configure(mode: .click, enabled: true)
        XCTAssertEqual(session.route(.keyDown(.a, modifiers: .command)), .passThrough)
        XCTAssertEqual(session.route(.keyUp(.a)), .passThrough)
    }

    func testPauseAndSecureInputClearMotionAndFailOpen() {
        for secure in [true, false] {
            var session = InputSession(preferences: UserPreferences())
            session.configure(mode: .scroll, enabled: true)
            _ = session.route(.keyDown(.j))
            XCTAssertEqual(session.scrollKeys, [.j])
            if !secure { session.configure(mode: .idle, enabled: false) }
            XCTAssertFalse(session.route(.keyUp(.j), secure: secure).shouldConsume)
            XCTAssertTrue(session.scrollKeys.isEmpty)
            XCTAssertEqual(session.router.mode, .idle)
        }
    }

    func testEscapeStopsRoutingSynchronously() {
        var session = InputSession(preferences: UserPreferences())
        session.configure(mode: .scroll, enabled: true)
        _ = session.route(.keyDown(.j))
        XCTAssertEqual(session.route(.keyDown(.escape)), RouteDecision(consuming: .cancel))
        XCTAssertEqual(session.router.mode, .idle)
        XCTAssertTrue(session.scrollKeys.isEmpty)
    }
}
