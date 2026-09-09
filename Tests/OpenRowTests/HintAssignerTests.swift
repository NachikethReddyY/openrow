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

    func testRetainsSingleKeysWhenMoreTargetsNeedLongerCodes() throws {
        let codes = try HintAssigner.codes(forCount: 10)

        XCTAssertEqual(codes.filter { $0.keys.count == 1 }.count, 8)
        XCTAssertEqual(codes.filter { $0.keys.count == 2 }.count, 2)
        XCTAssertEqual(codes[0].keys, [.a])
    }

    func testSupportsMaximumSnapshotWithoutDuplicates() throws {
        let codes = try HintAssigner.codes(forCount: 729)

        XCTAssertEqual(codes.count, 729)
        XCTAssertTrue(codes.contains { $0.keys.count == 1 })
        XCTAssertTrue(codes.allSatisfy { $0.keys.count <= 4 })
        XCTAssertEqual(Set(codes).count, 729)
    }

    func testMixedLengthsNeverMakeACompleteCodeAPrefixOfAnother() throws {
        for count in [10, 57, 81, 100, 300, 729] {
            let codes = try HintAssigner.codes(forCount: count)
            XCTAssertEqual(codes.count, count)
            for (index, code) in codes.enumerated() {
                XCTAssertFalse(codes.enumerated().contains { $0.offset != index && $0.element.keys.starts(with: code.keys) })
            }
        }
        let dense = try HintAssigner.codes(forCount: 100)
        XCTAssertEqual(Set(dense.map { $0.keys.count }), [1, 2, 3])
    }

    func testRejectsInvalidCounts() {
        XCTAssertThrowsError(try HintAssigner.codes(forCount: -1))
        XCTAssertThrowsError(try HintAssigner.codes(forCount: 730))
        XCTAssertEqual(try HintAssigner.codes(forCount: 0), [])
    }

    func testFilteringDimsNonmatchesAndSelectsCompletedCode() throws {
        let codes = [HintCode(keys: [.a]), HintCode(keys: [.s, .a]), HintCode(keys: [.s, .s])]

        let afterA = HintFilter.states(for: codes, prefix: [.a])
        XCTAssertEqual(afterA, [.selected, .dimmed, .dimmed])

        let afterS = HintFilter.states(for: codes, prefix: [.s])
        XCTAssertEqual(afterS, [.dimmed, .matching, .matching])
        XCTAssertEqual(HintFilter.states(for: codes, prefix: [.s, .a]), [.dimmed, .selected, .dimmed])
    }
}
