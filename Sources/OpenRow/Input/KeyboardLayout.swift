import AppKit
import Carbon

@MainActor enum KeyboardLayout {
    static func label(for key: KeyCode) -> String {
        let source = TISCopyCurrentKeyboardLayoutInputSource().takeRetainedValue()
        if let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) {
            let data = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue()
            if let bytes = CFDataGetBytePtr(data) {
                let layout = UnsafeRawPointer(bytes).assumingMemoryBound(to: UCKeyboardLayout.self)
                var deadKey: UInt32 = 0
                var length = 0
                var characters = [UniChar](repeating: 0, count: 8)
                let status = UCKeyTranslate(layout, key.rawValue, UInt16(kUCKeyActionDisplay), 0,
                    UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKey,
                    characters.count, &length, &characters)
                if status == noErr, length > 0 {
                    let value = String(utf16CodeUnits: characters, count: length).uppercased()
                    if value.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }), !value.trimmingCharacters(in: .whitespaces).isEmpty {
                        return value
                    }
                }
            }
        }
        if let hint = HintKey(keyCode: key) { return hint.rawValue.uppercased() }
        if key == .space { return "Space" }
        return "Key \(key.rawValue)"
    }

    static func description(_ shortcut: KeyboardShortcut) -> String {
        var parts: [String] = []
        if shortcut.modifiers.contains(.control) { parts.append("Control") }
        if shortcut.modifiers.contains(.option) { parts.append("Option") }
        if shortcut.modifiers.contains(.shift) { parts.append("Shift") }
        if shortcut.modifiers.contains(.command) { parts.append("Command") }
        parts.append(label(for: shortcut.keyCode))
        return parts.joined(separator: " + ")
    }
}

extension InputModifiers {
    init(flags: CGEventFlags) {
        self = []
        if flags.contains(.maskShift) { insert(.shift) }
        if flags.contains(.maskControl) { insert(.control) }
        if flags.contains(.maskAlternate) { insert(.option) }
        if flags.contains(.maskCommand) { insert(.command) }
    }

    init(flags: NSEvent.ModifierFlags) {
        self = []
        if flags.contains(.shift) { insert(.shift) }
        if flags.contains(.control) { insert(.control) }
        if flags.contains(.option) { insert(.option) }
        if flags.contains(.command) { insert(.command) }
    }
}
