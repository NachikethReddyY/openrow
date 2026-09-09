import Foundation

enum HintSize: String, Codable, CaseIterable, Sendable {
    case small, medium, large
    var title: String { rawValue.capitalized }
    var points: CGFloat {
        switch self { case .small: 8; case .medium: 9; case .large: 11 }
    }
}

struct UserPreferences: Codable, Equatable, Sendable {
    var clickShortcut = KeyboardShortcut(keyCode: .j, modifiers: .hyper)
    var scrollShortcut = KeyboardShortcut(keyCode: .k, modifiers: .hyper)
    var hintSize: HintSize = .medium
    var scrollSpeed: Double = 600
    var dashMultiplier: Double = 3
    var ignoredBundleIDs: [String] = []
    var paused = false
    var launchAtLogin = false
    var onboardingCompleted = false

    func sanitized() -> Self {
        var result = self
        result.scrollSpeed = scrollSpeed.isFinite ? min(1800, max(120, scrollSpeed)) : 600
        result.dashMultiplier = dashMultiplier.isFinite ? min(8, max(1, dashMultiplier)) : 3
        result.ignoredBundleIDs = Array(Set(ignoredBundleIDs.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty })).sorted()
        do {
            try ShortcutValidator.validate(clickShortcut, otherShortcut: scrollShortcut)
            try ShortcutValidator.validate(scrollShortcut, otherShortcut: clickShortcut)
        } catch {
            result.clickShortcut = Self().clickShortcut
            result.scrollShortcut = Self().scrollShortcut
        }
        return result
    }
}

struct PreferencesStore {
    static let key = "OpenRow.preferences.v1"
    let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func load() -> UserPreferences {
        guard let data = defaults.data(forKey: Self.key),
              let value = try? JSONDecoder().decode(UserPreferences.self, from: data)
        else { return UserPreferences() }
        return value.sanitized()
    }

    func save(_ value: UserPreferences) throws {
        defaults.set(try JSONEncoder().encode(value.sanitized()), forKey: Self.key)
    }
}
