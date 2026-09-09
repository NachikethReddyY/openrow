import AppKit
import ApplicationServices
import XCTest
@testable import OpenRow

/// Opt-in integration tests. They only control OpenRow and its disposable native fixture.
@MainActor final class NativeFlowTests: XCTestCase {
    private var fixture: NSRunningApplication!
    private var app: AXUIElement!

    override func setUp() async throws {
        guard ProcessInfo.processInfo.environment["OPENROW_NATIVE_TESTS"] == "1" else {
            throw XCTSkip("Set OPENROW_NATIVE_TESTS=1 to run the authorized macOS fixture integration tests.")
        }
        guard AXIsProcessTrusted() else { throw XCTSkip("The test host needs Accessibility permission.") }
        let path = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".build/OpenRowFixture.app")
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        fixture = try await NSWorkspace.shared.openApplication(at: path, configuration: configuration)
        app = AXUIElementCreateApplication(fixture.processIdentifier)
        try await waitUntil { NSWorkspace.shared.frontmostApplication?.processIdentifier == self.fixture.processIdentifier }
        try await waitUntil {
            let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
            return windows.first { $0[kCGWindowLayer as String] as? Int == 0 }?[kCGWindowOwnerPID as String] as? Int32 == self.fixture.processIdentifier
        }
        try await pause(0.4)
        key(.escape)
        for element in elements() where value(element, kAXRoleAttribute) as? String == "AXScrollBar" {
            _ = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, NSNumber(value: 0))
        }
        try await pause(0.1)
    }

    func testClickActsExactlyOnceAndEscapeCancels() async throws {
        try pressButton("Reset")
        let target = try XCTUnwrap(find(role: "AXButton", title: "Single click target"))
        let targetFrame = try XCTUnwrap(frame(target))
        let primary = NSScreen.screens.first?.frame.maxY ?? 0
        let screens = NSScreen.screens.map { ScreenGeometry.cocoaRect(fromQuartz: $0.frame, primaryScreenMaxY: primary) }
        let snapshots = try await AccessibilityService().discover(pid: fixture.processIdentifier, mode: .click, screens: screens)
        let index = try XCTUnwrap(snapshots.firstIndex { TargetPolicy.isUnchanged($0.frame, targetFrame) })
        let codes = try HintAssigner.codes(forCount: snapshots.count)
        key(.j, flags: [.maskControl, .maskAlternate, .maskShift, .maskCommand])
        try await waitUntil { self.overlayCount() > 0 }
        try await pause(0.7)
        for hint in codes[index].keys { key(hint.keyCode); try await pause(0.05) }
        try await waitUntil { self.textValues().contains(where: { $0.contains("Clicks: 1") }) }
        try await pause(0.25)
        XCTAssertTrue(textValues().contains(where: { $0.contains("Clicks: 1") }))
        XCTAssertTrue(textValues().contains(where: { $0.contains("Last control: Single click target") }))
        XCTAssertEqual(NSWorkspace.shared.frontmostApplication?.processIdentifier, fixture.processIdentifier)
        XCTAssertEqual(overlayCount(), 0)
        key(.j, flags: [.maskControl, .maskAlternate, .maskShift, .maskCommand])
        try await waitUntil { self.overlayCount() > 0 }
        key(.escape)
        try await waitUntil { self.overlayCount() == 0 }
        XCTAssertTrue(textValues().contains(where: { $0.contains("Clicks: 1") }))
    }

    func testScrollDirectionsDashKeyUpAndRegionSelection() async throws {
        let service = AccessibilityService()
        let primary = NSScreen.screens.first?.frame.maxY ?? 0
        let screens = NSScreen.screens.map { ScreenGeometry.cocoaRect(fromQuartz: $0.frame, primaryScreenMaxY: primary) }
        let regions = try await service.discover(pid: fixture.processIdentifier, mode: .scroll, screens: screens)
        XCTAssertEqual(regions.count, 2)
        let region = try XCTUnwrap(regions.first)
        let pointBeforeOverlay = await service.revalidate(region, screens: screens)
        XCTAssertNotNil(pointBeforeOverlay, "The unobscured fixture region must be actionable.")
        let originalPointer = NSEvent.mouseLocation
        key(.k, flags: [.maskControl, .maskAlternate, .maskShift, .maskCommand])
        try await waitUntil { self.overlayCount() > 0 }
        try await pause(0.5)
        let pointAfterOverlay = await service.revalidate(region, screens: screens)
        XCTAssertNotNil(pointAfterOverlay, "OpenRow's click-through overlay must not invalidate the region.")
        let before = try scrollPosition()
        keyDown(.j)
        try await pause(0.35)
        keyUp(.j)
        try await pause(0.08)
        let after = try scrollPosition()
        XCTAssertGreaterThan(after.y, before.y)
        try await pause(0.2)
        XCTAssertEqual(try scrollPosition(), after, "Releasing the key must stop scrolling.")
        keyDown(.k)
        try await pause(0.15)
        keyUp(.k)
        try await pause(0.08)
        XCTAssertLessThan(try scrollPosition().y, after.y)
        let left = try scrollPosition().x
        keyDown(.l)
        try await pause(0.2)
        keyUp(.l)
        try await pause(0.08)
        let right = try scrollPosition().x
        XCTAssertGreaterThan(right, left)
        keyDown(.h)
        try await pause(0.12)
        keyUp(.h)
        try await pause(0.08)
        XCTAssertLessThan(try scrollPosition().x, right)
        let dashStart = try scrollPosition().y
        keyDown(.j, flags: .maskShift)
        try await pause(0.2)
        keyUp(.j)
        try await pause(0.08)
        XCTAssertGreaterThan(try scrollPosition().y - dashStart, (after.y - before.y) * 0.9)
        key(.tab)
        try await pause(0.1)
        let mainBefore = try scrollPosition()
        keyDown(.j)
        try await pause(0.2)
        keyUp(.j)
        try await pause(0.08)
        XCTAssertEqual(try scrollPosition(), mainBefore, "Tab must target the independent region.")
        key(.number1)
        keyDown(.j)
        try await pause(0.1)
        keyUp(.j)
        try await pause(0.08)
        XCTAssertGreaterThan(try scrollPosition().y, mainBefore.y)
        XCTAssertEqual(NSEvent.mouseLocation, originalPointer)
        XCTAssertEqual(NSWorkspace.shared.frontmostApplication?.processIdentifier, fixture.processIdentifier)
        key(.escape)
        try await waitUntil { self.overlayCount() == 0 }
    }

    func testWebKitTargetAndPreciseScroll() async throws {
        let toggle = try XCTUnwrap(elements().first { value($0, "AXIdentifier") as? String == "fixture.webToggle" })
        _ = AXUIElementPerformAction(toggle, kAXPressAction as CFString)
        defer { _ = AXUIElementPerformAction(toggle, kAXPressAction as CFString) }
        try await waitUntil { self.find(role: "AXButton", title: "Web control 1") != nil }
        let button = try XCTUnwrap(find(role: "AXButton", title: "Web control 1"))
        let buttonFrame = try XCTUnwrap(frame(button))
        let primary = NSScreen.screens.first?.frame.maxY ?? 0
        let screens = NSScreen.screens.map { ScreenGeometry.cocoaRect(fromQuartz: $0.frame, primaryScreenMaxY: primary) }
        let service = AccessibilityService()
        let targets = try await service.discover(pid: fixture.processIdentifier, mode: .click, screens: screens)
        XCTAssertTrue(targets.contains { TargetPolicy.isUnchanged($0.frame, buttonFrame) })
        let regions = try await service.discover(pid: fixture.processIdentifier, mode: .scroll, screens: screens)
        let selected = try XCTUnwrap(regions.filter { $0.frame.contains(CGPoint(x: buttonFrame.midX, y: buttonFrame.midY)) }
            .min { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height })
        let region = try XCTUnwrap(elements().first { value($0, kAXRoleAttribute) as? String == "AXScrollArea" && frame($0).map { TargetPolicy.isUnchanged($0, selected.frame) } == true })
        let bar = try XCTUnwrap(value(region, kAXVerticalScrollBarAttribute)).self as! AXUIElement
        let before = try XCTUnwrap(value(bar, kAXValueAttribute) as? Double)
        let pointer = NSEvent.mouseLocation
        let succeeded = await service.scroll(selected, vector: CGVector(dx: 0, dy: -100), screens: screens, shouldContinue: { true })
        XCTAssertTrue(succeeded)
        try await pause(0.15)
        XCTAssertGreaterThan(try XCTUnwrap(value(bar, kAXValueAttribute) as? Double), before)
        XCTAssertEqual(NSEvent.mouseLocation, pointer)
    }

    func testWarmDiscoverySample() async throws {
        let service = AccessibilityService()
        let primary = NSScreen.screens.first?.frame.maxY ?? 0
        let screens = NSScreen.screens.map { ScreenGeometry.cocoaRect(fromQuartz: $0.frame, primaryScreenMaxY: primary) }
        _ = try await service.discover(pid: fixture.processIdentifier, mode: .click, screens: screens)
        var milliseconds: [Double] = []
        var count = 0
        for _ in 0..<30 {
            let start = ContinuousClock.now
            count = try await service.discover(pid: fixture.processIdentifier, mode: .click, screens: screens).count
            let duration = start.duration(to: .now).components
            milliseconds.append(Double(duration.seconds) * 1000 + Double(duration.attoseconds) / 1e15)
        }
        milliseconds.sort()
        let result = "30 warm AX discovery runs; targets=\(count); p50=\(milliseconds[14]) ms; p95=\(milliseconds[28]) ms; max=\(milliseconds[29]) ms. This excludes overlay paint.\n"
        let folder = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".evidence/openrow")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try result.write(to: folder.appendingPathComponent("discovery-performance.txt"), atomically: true, encoding: .utf8)
        XCTAssertGreaterThan(count, 50)
        XCTAssertLessThan(milliseconds[28], 300)
    }

    private func pause(_ seconds: Double) async throws { try await Task.sleep(for: .seconds(seconds)) }

    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<60 {
            if condition() { return }
            try await pause(0.05)
        }
        throw NSError(domain: "NativeFlowTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Timed out waiting for the fixture outcome."])
    }

    private func key(_ code: KeyCode, flags: CGEventFlags = []) { keyDown(code, flags: flags); keyUp(code, flags: flags) }
    private func keyDown(_ code: KeyCode, flags: CGEventFlags = []) { postKey(code, down: true, flags: flags) }
    private func keyUp(_ code: KeyCode, flags: CGEventFlags = []) { postKey(code, down: false, flags: flags) }
    private func postKey(_ code: KeyCode, down: Bool, flags: CGEventFlags) {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == fixture.processIdentifier else {
            XCTFail("Focus left the disposable fixture; no input was posted."); return
        }
        let event = CGEvent(keyboardEventSource: nil, virtualKey: code.rawValue, keyDown: down)!
        event.flags = flags
        event.post(tap: .cghidEventTap)
    }

    private func value(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var output: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, name as CFString, &output) == .success ? output : nil
    }

    private func elements() -> [AXUIElement] {
        var queue = [app!]
        var index = 0
        while index < queue.count, index < 2000 {
            let next = queue[index]; index += 1
            queue.append(contentsOf: value(next, kAXChildrenAttribute) as? [AXUIElement] ?? [])
        }
        return queue
    }

    private func find(role: String, title: String) -> AXUIElement? {
        elements().first { value($0, kAXRoleAttribute) as? String == role &&
            (value($0, kAXTitleAttribute) as? String == title || value($0, kAXDescriptionAttribute) as? String == title) }
    }
    private func pressButton(_ title: String) throws {
        let button = try XCTUnwrap(find(role: "AXButton", title: title))
        XCTAssertEqual(AXUIElementPerformAction(button, kAXPressAction as CFString), .success)
    }
    private func frame(_ element: AXUIElement) -> CGRect? {
        guard let p = value(element, kAXPositionAttribute), let s = value(element, kAXSizeAttribute) else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(p as! AXValue, .cgPoint, &position), AXValueGetValue(s as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: position, size: size)
    }
    private func textValues() -> [String] {
        elements().compactMap { value($0, kAXValueAttribute) as? String }
    }
    private func scrollPosition() throws -> CGPoint {
        let label = try XCTUnwrap(textValues().first { $0.contains("Scroll: x ") })
        let regex = try NSRegularExpression(pattern: "Scroll: x (-?[0-9]+), y (-?[0-9]+)")
        let match = try XCTUnwrap(regex.firstMatch(in: label, range: NSRange(label.startIndex..., in: label)))
        let ns = label as NSString
        return CGPoint(x: Double(ns.substring(with: match.range(at: 1)))!, y: Double(ns.substring(with: match.range(at: 2)))!)
    }
    private func overlayCount() -> Int {
        let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
        return windows.filter {
            $0[kCGWindowOwnerName as String] as? String == "OpenRow" && ($0[kCGWindowLayer as String] as? Int ?? 0) == Int(NSWindow.Level.popUpMenu.rawValue)
        }.count
    }
}
