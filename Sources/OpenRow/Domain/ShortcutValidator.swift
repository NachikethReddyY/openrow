import Foundation

enum ShortcutValidationError: LocalizedError, Equatable {
    case needsControlOptionOrCommand
    case reservedKey
    case conflictsWithOtherMode

    var errorDescription: String? {
        switch self {
        case .needsControlOptionOrCommand:
            "Include Command, Option, or Control."
        case .reservedKey:
            "That key is reserved for navigation or cancellation."
        case .conflictsWithOtherMode:
            "Click and Scroll modes need different shortcuts."
        }
    }
}

enum ShortcutValidator {
    static func validate(
        _ shortcut: KeyboardShortcut,
        otherShortcut: KeyboardShortcut?
    ) throws {
        let meaningfulModifiers: InputModifiers = [.control, .option, .command]
        guard !shortcut.modifiers.intersection(meaningfulModifiers).isEmpty else {
            throw ShortcutValidationError.needsControlOptionOrCommand
        }
        guard ![KeyCode.escape, .delete, .tab].contains(shortcut.keyCode) else {
            throw ShortcutValidationError.reservedKey
        }
        guard shortcut != otherShortcut else {
            throw ShortcutValidationError.conflictsWithOtherMode
        }
    }
}
