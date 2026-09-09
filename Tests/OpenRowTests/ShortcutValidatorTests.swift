import XCTest
@testable import OpenRow

final class ShortcutValidatorTests: XCTestCase {
    func testAcceptsAUniqueModifiedShortcut() throws {
        let candidate = KeyboardShortcut(keyCode: .j, modifiers: .hyper)
        let other = KeyboardShortcut(keyCode: .k, modifiers: .hyper)

        XCTAssertNoThrow(try ShortcutValidator.validate(candidate, otherShortcut: other))
    }

    func testRejectsUnmodifiedAndShiftOnlyShortcuts() {
        XCTAssertThrowsError(
            try ShortcutValidator.validate(
                KeyboardShortcut(keyCode: .j, modifiers: []),
                otherShortcut: nil
            )
        )
        XCTAssertThrowsError(
            try ShortcutValidator.validate(
                KeyboardShortcut(keyCode: .j, modifiers: .shift),
                otherShortcut: nil
            )
        )
    }

    func testRejectsEscapeDeleteTabAndConflicts() {
        let other = KeyboardShortcut(keyCode: .k, modifiers: .hyper)

        for keyCode in [KeyCode.escape, .delete, .tab] {
            XCTAssertThrowsError(
                try ShortcutValidator.validate(
                    KeyboardShortcut(keyCode: keyCode, modifiers: .hyper),
                    otherShortcut: nil
                )
            )
        }
        XCTAssertThrowsError(try ShortcutValidator.validate(other, otherShortcut: other))
    }
}

