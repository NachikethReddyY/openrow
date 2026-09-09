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

        let alphabet = HintKey.allCases
        var leaves = alphabet.prefix(count).map { HintCode(keys: [$0]) }
        // Keep easy single-key targets. Expand other leaves, never a prefix of an existing leaf.
        // A dense screen can need four keys in exchange for retaining the short codes.
        while leaves.count < count {
            let shortest = leaves.dropFirst(4).map { $0.keys.count }.min()!
            let index = leaves.lastIndex { $0.keys.count == shortest }!
            let parent = leaves.remove(at: index)
            let children = alphabet.prefix(min(alphabet.count, count - leaves.count)).map { HintCode(keys: parent.keys + [$0]) }
            leaves.insert(contentsOf: children, at: index)
        }
        return leaves.sorted { $0.keys.count < $1.keys.count }
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
