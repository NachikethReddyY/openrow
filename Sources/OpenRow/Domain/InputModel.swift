import Foundation

struct KeyCode: RawRepresentable, Codable, Hashable, Sendable, ExpressibleByIntegerLiteral {
    let rawValue: UInt16

    init(rawValue: UInt16) {
        self.rawValue = rawValue
    }

    init(_ rawValue: UInt16) {
        self.rawValue = rawValue
    }

    init(integerLiteral value: UInt16) {
        rawValue = value
    }

    static let a: Self = 0
    static let s: Self = 1
    static let d: Self = 2
    static let f: Self = 3
    static let h: Self = 4
    static let g: Self = 5
    static let z: Self = 6
    static let x: Self = 7
    static let c: Self = 8
    static let v: Self = 9
    static let b: Self = 11
    static let q: Self = 12
    static let w: Self = 13
    static let e: Self = 14
    static let r: Self = 15
    static let y: Self = 16
    static let t: Self = 17
    static let number1: Self = 18
    static let number2: Self = 19
    static let number3: Self = 20
    static let number4: Self = 21
    static let number6: Self = 22
    static let number5: Self = 23
    static let equal: Self = 24
    static let number9: Self = 25
    static let number7: Self = 26
    static let minus: Self = 27
    static let number8: Self = 28
    static let number0: Self = 29
    static let rightBracket: Self = 30
    static let o: Self = 31
    static let u: Self = 32
    static let leftBracket: Self = 33
    static let i: Self = 34
    static let p: Self = 35
    static let l: Self = 37
    static let j: Self = 38
    static let quote: Self = 39
    static let k: Self = 40
    static let semicolon: Self = 41
    static let backslash: Self = 42
    static let comma: Self = 43
    static let slash: Self = 44
    static let n: Self = 45
    static let m: Self = 46
    static let period: Self = 47
    static let tab: Self = 48
    static let space: Self = 49
    static let delete: Self = 51
    static let escape: Self = 53
}

struct InputModifiers: OptionSet, Codable, Hashable, Sendable {
    let rawValue: UInt64

    init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    static let shift = Self(rawValue: 1 << 0)
    static let control = Self(rawValue: 1 << 1)
    static let option = Self(rawValue: 1 << 2)
    static let command = Self(rawValue: 1 << 3)
    static let capsLock = Self(rawValue: 1 << 4)
    static let function = Self(rawValue: 1 << 5)
    static let hyper: Self = [.control, .option, .shift, .command]

    var shortcutRelevant: Self {
        intersection([.shift, .control, .option, .command])
    }
}

struct KeyboardShortcut: Codable, Equatable, Sendable {
    let keyCode: KeyCode
    let modifiers: InputModifiers

    init(keyCode: KeyCode, modifiers: InputModifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers.shortcutRelevant
    }

    func matches(keyCode: KeyCode, modifiers: InputModifiers) -> Bool {
        self.keyCode == keyCode && self.modifiers == modifiers.shortcutRelevant
    }
}

enum OpenRowMode: Equatable, Sendable {
    case idle
    case click
    case scroll
}

enum ScrollDirection: Equatable, Hashable, Sendable {
    case left
    case down
    case up
    case right
}

enum InputEvent: Equatable, Sendable {
    case keyDown(KeyCode, modifiers: InputModifiers = [], isRepeat: Bool = false)
    case keyUp(KeyCode, modifiers: InputModifiers = [])
    case tapDisabled
}

enum InputCommand: Equatable, Sendable {
    case activateClick
    case activateScroll
    case appendHint(HintKey)
    case deleteHint
    case setScroll(ScrollDirection, pressed: Bool, dash: Bool)
    case cycleRegion
    case selectRegion(Int)
    case cancel
    case tapFailed
}

struct RouteDecision: Equatable, Sendable {
    let shouldConsume: Bool
    let command: InputCommand?

    init(shouldConsume: Bool, command: InputCommand?) {
        self.shouldConsume = shouldConsume
        self.command = command
    }

    init(consuming command: InputCommand) {
        self.init(shouldConsume: true, command: command)
    }

    init(passingThrough command: InputCommand) {
        self.init(shouldConsume: false, command: command)
    }

    static let consumeOnly = Self(shouldConsume: true, command: nil)
    static let passThrough = Self(shouldConsume: false, command: nil)
}

struct InputRouter: Sendable {
    let clickShortcut: KeyboardShortcut
    let scrollShortcut: KeyboardShortcut
    var mode: OpenRowMode = .idle

    mutating func route(_ event: InputEvent) -> RouteDecision {
        if event == .tapDisabled {
            mode = .idle
            return RouteDecision(passingThrough: .tapFailed)
        }

        switch event {
        case let .keyDown(keyCode, modifiers, isRepeat):
            if clickShortcut.matches(keyCode: keyCode, modifiers: modifiers) {
                return isRepeat ? .consumeOnly : RouteDecision(consuming: .activateClick)
            }
            if scrollShortcut.matches(keyCode: keyCode, modifiers: modifiers) {
                return isRepeat ? .consumeOnly : RouteDecision(consuming: .activateScroll)
            }
            return routeKeyDown(keyCode, modifiers: modifiers, isRepeat: isRepeat)

        case let .keyUp(keyCode, modifiers):
            if clickShortcut.matches(keyCode: keyCode, modifiers: modifiers)
                || scrollShortcut.matches(keyCode: keyCode, modifiers: modifiers)
            {
                return .consumeOnly
            }
            return routeKeyUp(keyCode, modifiers: modifiers)

        case .tapDisabled:
            return .passThrough
        }
    }

    private func routeKeyDown(
        _ keyCode: KeyCode,
        modifiers: InputModifiers,
        isRepeat: Bool
    ) -> RouteDecision {
        switch mode {
        case .idle:
            return .passThrough

        case .click:
            if keyCode == .escape { return RouteDecision(consuming: .cancel) }
            if keyCode == .delete { return isRepeat ? .consumeOnly : RouteDecision(consuming: .deleteHint) }
            guard let hintKey = HintKey(keyCode: keyCode), modifiers.shortcutRelevant.isEmpty else {
                return .passThrough
            }
            return isRepeat ? .consumeOnly : RouteDecision(consuming: .appendHint(hintKey))

        case .scroll:
            if keyCode == .escape { return RouteDecision(consuming: .cancel) }
            if keyCode == .tab { return isRepeat ? .consumeOnly : RouteDecision(consuming: .cycleRegion) }
            if let index = regionIndex(for: keyCode) {
                return isRepeat ? .consumeOnly : RouteDecision(consuming: .selectRegion(index))
            }
            guard let direction = scrollDirection(for: keyCode),
                  modifiers.shortcutRelevant.subtracting(.shift).isEmpty
            else {
                return .passThrough
            }
            return RouteDecision(consuming: .setScroll(direction, pressed: true, dash: modifiers.contains(.shift)))
        }
    }

    private func routeKeyUp(_ keyCode: KeyCode, modifiers: InputModifiers) -> RouteDecision {
        switch mode {
        case .idle:
            return .passThrough
        case .click:
            if keyCode == .escape || keyCode == .delete || HintKey(keyCode: keyCode) != nil {
                return .consumeOnly
            }
            return .passThrough
        case .scroll:
            if let direction = scrollDirection(for: keyCode) {
                return RouteDecision(consuming: .setScroll(direction, pressed: false, dash: modifiers.contains(.shift)))
            }
            if keyCode == .escape || keyCode == .tab || regionIndex(for: keyCode) != nil {
                return .consumeOnly
            }
            return .passThrough
        }
    }

    private func scrollDirection(for keyCode: KeyCode) -> ScrollDirection? {
        switch keyCode {
        case .h: .left
        case .j: .down
        case .k: .up
        case .l: .right
        default: nil
        }
    }

    private func regionIndex(for keyCode: KeyCode) -> Int? {
        switch keyCode {
        case .number1: 0
        case .number2: 1
        case .number3: 2
        case .number4: 3
        case .number5: 4
        case .number6: 5
        case .number7: 6
        case .number8: 7
        case .number9: 8
        default: nil
        }
    }
}
