import AppKit
import AVFAudio
import ApplicationServices
import XCTest
@testable import OpenRow

@MainActor final class MissionControlNativeTests: XCTestCase {
    func testLiveCardsKeepIdentityAndRejectUnknownSelection() async throws {
        guard ProcessInfo.processInfo.environment["OPENROW_MISSION_CONTROL_TESTS"] == "1" else {
            throw XCTSkip("Open Mission Control and set OPENROW_MISSION_CONTROL_TESTS=1 for this read-only live check.")
        }
        XCTAssertTrue(AXIsProcessTrusted())
        let dock = try XCTUnwrap(NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first)
        let screens = OverlayController().displays.map(\.quartzFrame)
        let service = MissionControlService()
        let first = await service.snapshot(pid: dock.processIdentifier, screens: screens)
        XCTAssertTrue(first.active, "Mission Control must remain open during this check.")
        XCTAssertFalse(first.targets.isEmpty)
        let second = await service.snapshot(pid: dock.processIdentifier, screens: screens)
        XCTAssertEqual(first.targets.map(\.id), second.targets.map(\.id))
        let invalid = TargetSnapshot(id: -1, pid: dock.processIdentifier, frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        let selected = await service.select(invalid, screens: screens)
        XCTAssertFalse(selected, "Unknown IDs must not trigger a click or press.")
        let monitor = MissionControlMonitor()
        monitor.screens = { screens }
        let observed = expectation(description: "Monitor detects already-open Mission Control")
        monitor.onChange = { snapshot in
            if snapshot.active && !snapshot.targets.isEmpty { observed.fulfill(); monitor.onChange = nil }
        }
        monitor.start()
        await fulfillment(of: [observed], timeout: 3)
        monitor.stop()
    }

    func testEntryDetectionPresentsLiveCards() async throws {
        guard ProcessInfo.processInfo.environment["OPENROW_MISSION_ENTRY_TEST"] == "1" else {
            throw XCTSkip("Manual Mission Control entry required.")
        }
        let monitor = MissionControlMonitor()
        monitor.screens = { OverlayController().displays.map(\.quartzFrame) }
        let observed = expectation(description: "Monitor discovers window cards after entry")
        monitor.onChange = { snapshot in
            print("Mission monitor active=\(snapshot.active) cards=\(snapshot.targets.count)")
            if snapshot.active && !snapshot.targets.isEmpty { observed.fulfill(); monitor.onChange = nil }
        }
        monitor.start()
        print("MISSION CONTROL OBSERVER READY")
        await fulfillment(of: [observed], timeout: 300)
        monitor.stop()
    }

    func testDetectsEntryWithoutAnAccessibilityNotificationAndStopsCleanly() async throws {
        var reads = 0
        let card = TargetSnapshot(id: 1, pid: 1, frame: CGRect(x: 100, y: 100, width: 300, height: 200))
        let monitor = MissionControlMonitor { _, _ in
            reads += 1
            return MissionControlService.Snapshot(active: reads >= 2, targets: reads >= 2 ? [card] : [])
        }
        let presented = expectation(description: "Polling discovers delayed entry without an event")
        monitor.onChange = { snapshot in
            if snapshot.active {
                presented.fulfill()
                monitor.stop()
            }
        }
        monitor.start()
        await fulfillment(of: [presented], timeout: 2)
        let stoppedCount = reads
        try await Task.sleep(for: .milliseconds(650))
        XCTAssertEqual(reads, stoppedCount, "Stopping must cancel all future accessibility checks.")
    }

    func testAppearanceSoundIsShortAndAvailable() throws {
        let sound = try XCTUnwrap(NSSound(named: "Pop"))
        XCTAssertGreaterThan(sound.duration, 0)
        // macOS's Pop has a short audible transient followed by silence.
        let file = try AVAudioFile(forReading: URL(fileURLWithPath: "/System/Library/Sounds/Pop.aiff"))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)))
        try file.read(into: buffer)
        let channels = try XCTUnwrap(buffer.floatChannelData)
        var lastAudibleFrame = 0
        for channel in 0..<Int(buffer.format.channelCount) {
            for index in 0..<Int(buffer.frameLength) where abs(channels[channel][index]) > 0.006 {
                lastAudibleFrame = max(lastAudibleFrame, index)
            }
        }
        XCTAssertGreaterThan(lastAudibleFrame, 0)
        XCTAssertLessThan(Double(lastAudibleFrame) / buffer.format.sampleRate, 0.5)
    }
}
