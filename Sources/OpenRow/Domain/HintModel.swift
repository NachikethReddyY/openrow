import Foundation

enum HintKey: String, CaseIterable, Codable, Hashable, Sendable {
    case a, s, d, f, g, h, j, k, l

    var keyCode: KeyCode {
        switch self {
        case .a: .a
        case .s: .s
        case .d: .d
        case .f: .f
        case .g: .g
        case .h: .h
        case .j: .j
        case .k: .k
        case .l: .l
        }
    }

    init?(keyCode: KeyCode) {
        guard let key = Self.allCases.first(where: { $0.keyCode == keyCode }) else { return nil }
        self = key
    }
}

struct HintCode: Hashable, Sendable {
    let keys: [HintKey]
}

enum HintAssignerError: Error, Equatable {
    case invalidCount(Int)
}

enum HintAssigner {
    static let maximumCount = 729

    static func codes(forCount count: Int) throws -> [HintCode] {
        guard (0...maximumCount).contains(count) else {
            throw HintAssignerError.invalidCount(count)
        }
        guard count > 0 else { return [] }

        let length = count <= 9 ? 1 : count <= 81 ? 2 : 3
        let alphabet = HintKey.allCases

        return (0..<count).map { value in
            var remainder = value
            var keys = Array(repeating: alphabet[0], count: length)
            for position in (0..<length).reversed() {
                keys[position] = alphabet[remainder % alphabet.count]
                remainder /= alphabet.count
            }
            return HintCode(keys: keys)
        }
    }
}

enum HintFilterState: Equatable, Sendable {
    case matching
    case selected
    case dimmed
}

enum HintFilter {
    static func states(for codes: [HintCode], prefix: [HintKey]) -> [HintFilterState] {
        codes.map { code in
            guard code.keys.starts(with: prefix) else { return .dimmed }
            return code.keys.count == prefix.count ? .selected : .matching
        }
    }
}

