import XCTest
@testable import OpenRow

final class MissionControlSessionTests: XCTestCase {
    func testWaitsForCardsThenPresentsOnlyOnce() {
        var session = MissionControlSession()
        XCTAssertEqual(session.update(active: true, canPresent: true, hasTargets: false), .none)
        XCTAssertEqual(session.update(active: true, canPresent: true, hasTargets: true), .present)
        XCTAssertEqual(session.update(active: true, canPresent: true, hasTargets: true), .none)
    }

    func testEscapeSuppressesReappearanceUntilNextEntry() {
        var session = MissionControlSession()
        _ = session.update(active: true, canPresent: true, hasTargets: true)
        session.dismiss()
        XCTAssertEqual(session.update(active: true, canPresent: true, hasTargets: true), .none)
        XCTAssertEqual(session.update(active: false, canPresent: true, hasTargets: false), .hide)
        XCTAssertEqual(session.update(active: true, canPresent: true, hasTargets: true), .present)
    }

    func testPermissionPauseOrSecureInputSuppressesCurrentVisit() {
        var session = MissionControlSession()
        XCTAssertEqual(session.update(active: true, canPresent: false, hasTargets: true), .hide)
        XCTAssertEqual(session.update(active: true, canPresent: true, hasTargets: true), .none)
        _ = session.update(active: false, canPresent: true, hasTargets: false)
        XCTAssertEqual(session.update(active: true, canPresent: true, hasTargets: true), .present)
    }

    func testExitBeforeDiscoveryDoesNotPresentStaleCards() {
        var session = MissionControlSession()
        _ = session.update(active: true, canPresent: true, hasTargets: false)
        XCTAssertEqual(session.update(active: false, canPresent: true, hasTargets: true), .hide)
        XCTAssertEqual(session.update(active: false, canPresent: true, hasTargets: true), .none)
    }
}
