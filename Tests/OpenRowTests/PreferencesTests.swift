import XCTest
@testable import OpenRow

final class PreferencesTests: XCTestCase {
    func testDefaultsAndRoundTrip() throws {
        let name = "OpenRowTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = PreferencesStore(defaults: defaults)
        XCTAssertEqual(store.load(), UserPreferences())
        var value = UserPreferences()
        value.clickShortcut = KeyboardShortcut(keyCode: .c, modifiers: [.command, .option])
        value.hintSize = .large
        value.scrollSpeed = 900
        value.dashMultiplier = 5
        value.ignoredBundleIDs = ["com.example.fixture"]
        value.paused = true
        value.launchAtLogin = true
        value.onboardingCompleted = true
        try store.save(value)
        XCTAssertEqual(store.load(), value)
    }

    func testCorruptDataAndInvalidValuesRecoverSafely() throws {
        let name = "OpenRowTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = PreferencesStore(defaults: defaults)
        defaults.set(Data("bad data".utf8), forKey: PreferencesStore.key)
        XCTAssertEqual(store.load(), UserPreferences())
        var value = UserPreferences()
        value.scrollSpeed = -1
        value.dashMultiplier = 100
        value.scrollShortcut = value.clickShortcut
        value.ignoredBundleIDs = [" ", "com.example.app", "com.example.app"]
        try store.save(value)
        let repaired = store.load()
        XCTAssertEqual(repaired.scrollSpeed, 120)
        XCTAssertEqual(repaired.dashMultiplier, 8)
        XCTAssertNotEqual(repaired.clickShortcut, repaired.scrollShortcut)
        XCTAssertEqual(repaired.ignoredBundleIDs, ["com.example.app"])
    }
}
