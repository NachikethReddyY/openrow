import XCTest
@testable import OpenRow

final class HintAssignerTests: XCTestCase {
    func testUsesOneFixedKeyForUpToNineTargets() throws {
        let codes = try HintAssigner.codes(forCount: 9)

        XCTAssertEqual(codes.count, 9)
        XCTAssertTrue(codes.allSatisfy { $0.keys.count == 1 })
        XCTAssertEqual(Set(codes).count, 9)
        XCTAssertEqual(codes.first?.keys, [.a])
        XCTAssertEqual(codes.last?.keys, [.l])
    }

    func testUsesTwoFixedKeysStartingAtTenTargets() throws {
        let codes = try HintAssigner.codes(forCount: 10)

        XCTAssertTrue(codes.allSatisfy { $0.keys.count == 2 })
        XCTAssertEqual(codes[0].keys, [.a, .a])
        XCTAssertEqual(codes[8].keys, [.a, .l])
        XCTAssertEqual(codes[9].keys, [.s, .a])
    }

    func testSupportsMaximumSnapshotWithoutDuplicates() throws {
        let codes = try HintAssigner.codes(forCount: 729)

        XCTAssertEqual(codes.count, 729)
        XCTAssertTrue(codes.allSatisfy { $0.keys.count == 3 })
        XCTAssertEqual(Set(codes).count, 729)
    }

    func testRejectsInvalidCounts() {
        XCTAssertThrowsError(try HintAssigner.codes(forCount: -1))
        XCTAssertThrowsError(try HintAssigner.codes(forCount: 730))
        XCTAssertEqual(try HintAssigner.codes(forCount: 0), [])
    }

    func testFilteringDimsNonmatchesAndSelectsCompletedCode() throws {
        let codes = try HintAssigner.codes(forCount: 10)

        let afterA = HintFilter.states(for: codes, prefix: [.a])
        XCTAssertEqual(afterA.filter { $0 == .matching }.count, 9)
        XCTAssertEqual(afterA.filter { $0 == .dimmed }.count, 1)

        let afterAA = HintFilter.states(for: codes, prefix: [.a, .a])
        XCTAssertEqual(afterAA[0], .selected)
        XCTAssertTrue(afterAA.dropFirst().allSatisfy { $0 == .dimmed })
    }
}

