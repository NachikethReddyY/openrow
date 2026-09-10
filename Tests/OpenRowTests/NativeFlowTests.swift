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
        // Start each independent flow with a fresh fixture; closed secondary-window
        // AX handles and previous WebKit state must not leak into the next test.
        for previous in NSWorkspace.shared.runningApplications where previous.bundleIdentifier == "dev.openrow.OpenRowFixture" {
            previous.terminate()
            try await waitUntil { previous.isTerminated }
        }
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
        if let toggle = elements().first(where: { value($0, "AXIdentifier") as? String == "fixture.tabSidebarToggle" }),
           (value(toggle, kAXValueAttribute) as? NSNumber)?.boolValue == true {
            _ = AXUIElementPerformAction(toggle, kAXPressAction as CFString)
        }
        // Keep the disposable window on screen; persisted offscreen placement changes
        // both hit-test visibility and which controls the 100-hint sample can reach.
        if let window = value(app, kAXFocusedWindowAttribute) {
            var position = CGPoint(x: 120, y: 100)
            var size = CGSize(width: 1000, height: 720)
            _ = AXUIElementSetAttributeValue(window as! AXUIElement, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &position)!)
            _ = AXUIElementSetAttributeValue(window as! AXUIElement, kAXSizeAttribute as CFString, AXValueCreate(.cgSize, &size)!)
        }
        if elements().contains(where: { value($0, kAXRoleAttribute) as? String == "AXWebArea" }),
           let toggle = elements().first(where: { value($0, "AXIdentifier") as? String == "fixture.webToggle" }) {
            _ = AXUIElementPerformAction(toggle, kAXPressAction as CFString)
            try await waitUntil { !self.elements().contains { self.value($0, kAXRoleAttribute) as? String == "AXWebArea" } }
        }
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
        let window = try XCTUnwrap(elements().first { value($0, kAXRoleAttribute) as? String == "AXWindow" })
        var originalOrigin = try XCTUnwrap(frame(window)).origin
        var movedOrigin = CGPoint(x: originalOrigin.x - 90, y: originalOrigin.y + 35)
        XCTAssertEqual(AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &movedOrigin)!), .success)
        defer { _ = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &originalOrigin)!) }
        let toggle = try XCTUnwrap(elements().first { value($0, "AXIdentifier") as? String == "fixture.webToggle" })
        _ = AXUIElementPerformAction(toggle, kAXPressAction as CFString)
        defer { _ = AXUIElementPerformAction(toggle, kAXPressAction as CFString) }
        try await waitUntil { self.find(role: "AXButton", title: "Web control 1") != nil }
        try await waitUntil {
            guard let group = self.elements().first(where: { self.value($0, kAXDescriptionAttribute) as? String == "Web controls" }),
                  let frame = self.frame(group) else { return false }
            return frame.width > 80 && frame.height > 80
        }
        let button = try XCTUnwrap(find(role: "AXButton", title: "Web control 1"))
        let buttonFrame = try XCTUnwrap(frame(button))
        let primary = NSScreen.screens.first?.frame.maxY ?? 0
        let screens = NSScreen.screens.map { ScreenGeometry.cocoaRect(fromQuartz: $0.frame, primaryScreenMaxY: primary) }
        let service = AccessibilityService()
        let targets = try await service.discover(pid: fixture.processIdentifier, mode: .click, screens: screens)
        XCTAssertTrue(targets.contains { TargetPolicy.isUnchanged($0.frame, buttonFrame) })
        let regions = try await AccessibilityService().discover(pid: fixture.processIdentifier, mode: .scroll, screens: screens)
        XCTAssertEqual(regions.count, 3, "The page and both nested overflow regions must be reachable.")
        let group = try XCTUnwrap(elements().first { value($0, kAXDescriptionAttribute) as? String == "Web controls" })
        let groupFrame = try XCTUnwrap(frame(group))
        let index = try XCTUnwrap(regions.firstIndex { abs($0.frame.minX - groupFrame.minX) < 1 && abs($0.frame.minY - groupFrame.minY) < 1 })
        let codes = try HintAssigner.codes(forCount: targets.count)
        let buttonIndex = try XCTUnwrap(targets.firstIndex { TargetPolicy.isUnchanged($0.frame, buttonFrame) })
        let validation = await service.revalidate(targets[buttonIndex], screens: screens)
        XCTAssertNotNil(validation, "A WebKit target behind an unambiguous native wrapper must remain actionable.")
        key(.j, flags: [.maskControl, .maskAlternate, .maskShift, .maskCommand])
        try await waitUntil { self.overlayCount() > 0 }
        try await pause(0.7)
        try captureFixture("browser-hints")
        for hint in codes[buttonIndex].keys { key(hint.keyCode); try await pause(0.05) }
        try await waitUntil { self.textValues().contains { $0.contains("Web clicks: 1") } }
        // Let the posted click finish before taking the cursor baseline for scrolling.
        try await pause(0.1)
        let pointer = NSEvent.mouseLocation
        key(.k, flags: [.maskControl, .maskAlternate, .maskShift, .maskCommand])
        try await waitUntil { self.overlayCount() > 0 }
        try await pause(0.5)
        let digits: [KeyCode] = [.number1, .number2, .number3, .number4, .number5, .number6, .number7, .number8, .number9]
        key(digits[index])
        let before = try await webPosition()
        keyDown(.j); try await pause(0.25); keyUp(.j); try await pause(0.1)
        let down = try await webPosition()
        XCTAssertGreaterThan(down.y, before.y)
        try await pause(0.2)
        let stopped = try await webPosition()
        XCTAssertEqual(stopped, down, "Browser key-up must stop immediately, without momentum.")
        keyDown(.k); try await pause(0.12); keyUp(.k); try await pause(0.1)
        let up = try await webPosition().y
        XCTAssertLessThan(up, down.y)
        keyDown(.l); try await pause(0.2); keyUp(.l); try await pause(0.1)
        let right = try await webPosition()
        XCTAssertGreaterThan(right.x, 0)
        keyDown(.h); try await pause(0.12); keyUp(.h); try await pause(0.1)
        let left = try await webPosition().x
        XCTAssertLessThan(left, right.x)
        let dashStart = try await webPosition().y
        keyDown(.j, flags: .maskShift); try await pause(0.15); keyUp(.j); try await pause(0.1)
        let dash = try await webPosition().y - dashStart
        XCTAssertGreaterThan(dash, down.y - before.y)
        let firstRegion = try await webPosition()
        key(.tab)
        keyDown(.j); try await pause(0.2); keyUp(.j); try await pause(0.1)
        let unchangedFirst = try await webPosition()
        XCTAssertEqual(unchangedFirst, firstRegion)
        let secondRegion = try await webPosition(reference: true).y
        XCTAssertGreaterThan(secondRegion, 0)
        try captureFixture("browser-scroll")
        keyDown(.j); try await pause(0.08); key(.escape); try await pause(0.1)
        let cancelled = try await webPosition(reference: true)
        try await pause(0.2)
        let afterCancel = try await webPosition(reference: true)
        XCTAssertEqual(afterCancel, cancelled, "Escape must cancel a held browser scroll key.")
        keyUp(.j)
        XCTAssertEqual(overlayCount(), 0)
        let heading = try XCTUnwrap(elements().first { value($0, kAXValueAttribute) as? String == "WebKit controls and nested scrolling" })
        let pageBefore = try XCTUnwrap(frame(heading)).minY
        let controlsBeforePage = try await webPosition()
        let referenceBeforePage = try await webPosition(reference: true)
        key(.k, flags: [.maskControl, .maskAlternate, .maskShift, .maskCommand])
        try await waitUntil { self.overlayCount() > 0 }
        try await pause(0.5)
        keyDown(.j); try await pause(0.2); keyUp(.j); try await pause(0.1)
        XCTAssertLessThan(try XCTUnwrap(frame(heading)).minY, pageBefore, "The browser page itself must scroll too.")
        let controlsAfterPage = try await webPosition()
        XCTAssertEqual(controlsAfterPage, controlsBeforePage)
        let referenceAfterPage = try await webPosition(reference: true)
        XCTAssertEqual(referenceAfterPage, referenceBeforePage)
        key(.escape)
        // AppKit can report subpixel differences after a fractional web-text click.
        // A scroll must never visibly reposition the pointer toward its region.
        XCTAssertEqual(NSEvent.mouseLocation.x, pointer.x, accuracy: 1)
        XCTAssertEqual(NSEvent.mouseLocation.y, pointer.y, accuracy: 1)
        XCTAssertEqual(NSWorkspace.shared.frontmostApplication?.processIdentifier, fixture.processIdentifier)
    }

    func testCompoundWebRowAndNestedButtonActIndependently() async throws {
        let toggle = try XCTUnwrap(elements().first { value($0, "AXIdentifier") as? String == "fixture.webToggle" })
        _ = AXUIElementPerformAction(toggle, kAXPressAction as CFString)
        defer { _ = AXUIElementPerformAction(toggle, kAXPressAction as CFString) }
        try await waitUntil { self.find(role: "AXLink", title: "Compound row") != nil }
        let rowFrame = try XCTUnwrap(find(role: "AXLink", title: "Compound row").flatMap { frame($0) })
        let childFrame = try XCTUnwrap(find(role: "AXButton", title: "Row accessory").flatMap { frame($0) })
        let overlay = OverlayController()
        let service = AccessibilityService()
        let screens = overlay.displays.map(\.quartzFrame)
        let targets = try await service.discover(pid: fixture.processIdentifier, mode: .click, screens: screens)
        let rowIndex = try XCTUnwrap(targets.firstIndex { TargetPolicy.isUnchanged($0.frame, rowFrame) })
        let childIndex = try XCTUnwrap(targets.firstIndex { TargetPolicy.isUnchanged($0.frame, childFrame) })
        XCTAssertEqual(targets.filter { rowFrame.contains($0.frame) }.count, 2,
            "One row action plus one independent accessory; no hints on the row's text/artwork.")
        let rowPoint = try XCTUnwrap(targets[rowIndex].clickPoint)
        XCTAssertFalse(childFrame.contains(rowPoint), "The row action must avoid its centered accessory.")
        let content = try XCTUnwrap(targets[rowIndex].contentFrame)
        XCTAssertTrue(content.contains(rowPoint), "Padded rows must point to their visible artwork/text.")
        XCTAssertLessThan(content.width, rowFrame.width / 2)
        let validated = await service.revalidate(targets[rowIndex], screens: screens)
        XCTAssertEqual(validated, rowPoint)
        let codes = try HintAssigner.codes(forCount: targets.count)
        for (index, outcome) in [(rowIndex, "Row clicks: 1; accessory clicks: 0"), (childIndex, "Row clicks: 1; accessory clicks: 1")] {
            key(.j, flags: [.maskControl, .maskAlternate, .maskShift, .maskCommand])
            try await waitUntil { self.overlayCount() > 0 }
            try await pause(0.6)
            try captureFixture("compound-row-hints")
            for hint in codes[index].keys { key(hint.keyCode); try await pause(0.05) }
            try await waitUntil { self.textValues().contains { $0.contains(outcome) } }
            let clicked = ScreenGeometry.cocoaPoint(fromQuartz: try XCTUnwrap(targets[index].clickPoint),
                primaryScreenMaxY: NSScreen.screens.first!.frame.maxY)
            XCTAssertEqual(NSEvent.mouseLocation.x, clicked.x, accuracy: 1)
            XCTAssertEqual(NSEvent.mouseLocation.y, clicked.y, accuracy: 1)
        }
    }

    func testNativeTabSidebarWithoutScrollAreaIsScrollable() async throws {
        let toggle = try XCTUnwrap(elements().first { value($0, "AXIdentifier") as? String == "fixture.tabSidebarToggle" })
        _ = AXUIElementPerformAction(toggle, kAXPressAction as CFString)
        defer { _ = AXUIElementPerformAction(toggle, kAXPressAction as CFString) }
        try await waitUntil { self.find(role: "AXButton", title: "Sidebar tab 1") != nil }
        let sidebar = try XCTUnwrap(elements().first { value($0, "AXIdentifier") as? String == "fixture.tabSidebar" })
        XCTAssertEqual(value(sidebar, kAXRoleAttribute) as? String, "AXTabGroup")
        let tab = try XCTUnwrap(find(role: "AXButton", title: "Sidebar tab 1"))
        let before = try XCTUnwrap(frame(tab))
        let screens = OverlayController().displays.map(\.quartzFrame)
        let service = AccessibilityService()
        let regions = try await service.discover(pid: fixture.processIdentifier, mode: .scroll, screens: screens)
        XCTAssertEqual(regions.count, 1, "The sidebar and its wrappers must produce one region.")
        let point = await service.revalidate(try XCTUnwrap(regions.first), screens: screens)
        XCTAssertNotNil(point)
        let originalPointer = NSEvent.mouseLocation
        key(.k, flags: [.maskControl, .maskAlternate, .maskShift, .maskCommand])
        try await waitUntil { self.overlayCount() > 0 }
        try await pause(0.5)
        keyDown(.k); try await pause(0.3); keyUp(.k); try await pause(0.1)
        let after = try XCTUnwrap(frame(tab))
        XCTAssertGreaterThan(after.minY, before.minY)
        try await pause(0.15)
        XCTAssertEqual(frame(tab), after, "Key-up must stop sidebar scrolling.")
        keyDown(.j); try await pause(0.15); keyUp(.j); try await pause(0.1)
        XCTAssertLessThan(try XCTUnwrap(frame(tab)).minY, after.minY)
        key(.escape)
        try await waitUntil { self.overlayCount() == 0 }
        XCTAssertEqual(NSEvent.mouseLocation, originalPointer)
    }

    func testSwitchingWindowsRejectsStaleTargets() async throws {
        let toggle = try XCTUnwrap(elements().first { value($0, "AXIdentifier") as? String == "fixture.webToggle" })
        _ = AXUIElementPerformAction(toggle, kAXPressAction as CFString)
        defer { _ = AXUIElementPerformAction(toggle, kAXPressAction as CFString) }
        try await waitUntil { self.find(role: "AXButton", title: "Web control 1") != nil }
        let service = AccessibilityService()
        let primary = NSScreen.screens.first?.frame.maxY ?? 0
        let screens = NSScreen.screens.map { ScreenGeometry.cocoaRect(fromQuartz: $0.frame, primaryScreenMaxY: primary) }
        let targets = try await service.discover(pid: fixture.processIdentifier, mode: .scroll, screens: screens)
        let target = try XCTUnwrap(targets.last)
        let point = await service.revalidate(target, screens: screens)
        XCTAssertNotNil(point)
        let originalWindow = try XCTUnwrap(value(app, kAXFocusedWindowAttribute)) as! AXUIElement
        let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
        let number = try XCTUnwrap(windows.first { $0[kCGWindowOwnerPID as String] as? pid_t == fixture.processIdentifier && $0[kCGWindowLayer as String] as? Int == 0 }?[kCGWindowNumber as String] as? Int)
        let before = try await webPosition(reference: true)
        try pressButton("Open second window")
        try await waitUntil {
            guard let focused = self.value(self.app, kAXFocusedWindowAttribute) else { return false }
            return self.value(focused as! AXUIElement, kAXTitleAttribute) as? String == "Second Fixture"
        }
        let second = try XCTUnwrap(value(app, kAXFocusedWindowAttribute)) as! AXUIElement
        defer {
            if let close = value(second, kAXCloseButtonAttribute) { _ = AXUIElementPerformAction(close as! AXUIElement, kAXPressAction as CFString) }
            _ = AXUIElementPerformAction(originalWindow, kAXRaiseAction as CFString)
        }
        let stale = await service.revalidate(target, screens: screens)
        XCTAssertNil(stale)
        let scrolled = await service.scroll(target, vector: CGVector(dx: 0, dy: -100), screens: screens, shouldContinue: { true })
        XCTAssertFalse(scrolled)
        XCTAssertFalse(WindowScrollActions.scroll(pid: fixture.processIdentifier, windowNumber: number,
            at: try XCTUnwrap(point), vector: CGVector(dx: 0, dy: -100), shouldContinue: { true }))
        try await pause(0.15)
        let afterCancel = try await webPosition(reference: true)
        XCTAssertEqual(afterCancel, before)
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

    func testHundredHintDiscoveryAndDrawingBudget() async throws {
        let window = try XCTUnwrap(value(app, kAXFocusedWindowAttribute)) as! AXUIElement
        var originalSize = try XCTUnwrap(frame(window)).size
        var sampleSize = CGSize(width: 1100, height: 850)
        XCTAssertEqual(AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, AXValueCreate(.cgSize, &sampleSize)!), .success)
        defer { _ = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, AXValueCreate(.cgSize, &originalSize)!) }
        try await pause(0.2)
        let overlay = OverlayController()
        defer { overlay.hide() }
        let service = AccessibilityService()
        let screens = overlay.displays.map(\.quartzFrame)
        let first = try await service.discover(pid: fixture.processIdentifier, mode: .click, screens: screens)
        XCTAssertGreaterThanOrEqual(first.count, 100)
        overlay.showHints(targets: Array(first.prefix(100)), codes: try HintAssigner.codes(forCount: 100), prefix: [], size: .medium)
        try await pause(0.1)
        var milliseconds: [Double] = []
        for _ in 0..<30 {
            let start = ContinuousClock.now
            let targets = try await service.discover(pid: fixture.processIdentifier, mode: .click, screens: screens)
            overlay.showHints(targets: Array(targets.prefix(100)), codes: try HintAssigner.codes(forCount: 100), prefix: [], size: .medium)
            for panel in NSApplication.shared.windows where panel.level == .popUpMenu {
                panel.contentView?.displayIfNeeded()
            }
            let duration = start.duration(to: .now).components
            milliseconds.append(Double(duration.seconds) * 1000 + Double(duration.attoseconds) / 1e15)
        }
        milliseconds.sort()
        let result = "30 warm runs; discover \(first.count) fixture targets + draw 100 hints; p50=\(milliseconds[14]) ms; p95=\(milliseconds[28]) ms; max=\(milliseconds[29]) ms. Measures synchronous AppKit drawing, excluding event delivery and compositor presentation.\n"
        let folder = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".evidence/openrow")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try result.write(to: folder.appendingPathComponent("hundred-hint-performance.txt"), atomically: true, encoding: .utf8)
        XCTAssertLessThanOrEqual(milliseconds[14], 150)
        XCTAssertLessThanOrEqual(milliseconds[28], 300)
        XCTAssertLessThanOrEqual(milliseconds[29], 750)
    }

    private func pause(_ seconds: Double) async throws { try await Task.sleep(for: .seconds(seconds)) }

    private func captureFixture(_ name: String) throws {
        guard ProcessInfo.processInfo.environment["OPENROW_CAPTURE_EVIDENCE"] == "1" else { return }
        let windowFrame = try XCTUnwrap(elements().first(where: { value($0, kAXRoleAttribute) as? String == "AXWindow" }).flatMap { frame($0) })
        let capture = Process()
        capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        capture.arguments = ["-x", "-R", "\(Int(windowFrame.minX)),\(Int(windowFrame.minY)),\(Int(windowFrame.width)),\(Int(windowFrame.height))", ".evidence/openrow/\(name).png"]
        try capture.run(); capture.waitUntilExit()
        XCTAssertEqual(capture.terminationStatus, 0)
    }

    private func waitUntil(line: UInt = #line, _ condition: () -> Bool) async throws {
        for _ in 0..<60 {
            if condition() { return }
            try await pause(0.05)
        }
        throw NSError(domain: "NativeFlowTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Timed out waiting for the fixture outcome at line \(line)."])
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
    private func webPosition(reference: Bool = false) async throws -> CGPoint {
        let prefix = reference ? "Web reference" : "Web controls"
        // WebKit briefly replaces the AX text node when its scroll status changes.
        var currentLabel: String?
        try await waitUntil {
            currentLabel = self.textValues().first { $0.contains("\(prefix): x ") }
            return currentLabel != nil
        }
        let label = try XCTUnwrap(currentLabel)
        let regex = try NSRegularExpression(pattern: "\(prefix): x (-?[0-9]+), y (-?[0-9]+)")
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
