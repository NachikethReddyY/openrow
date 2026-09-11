import AppKit
import ApplicationServices

private func missionControlChanged(_ observer: AXObserver, _ element: AXUIElement,
                                   _ notification: CFString, _ context: UnsafeMutableRawPointer?) {
    guard let context else { return }
    let monitor = Unmanaged<MissionControlMonitor>.fromOpaque(context).takeUnretainedValue()
    // This observer is attached exclusively to the main run loop.
    MainActor.assumeIsolated {
        monitor.refresh()
    }
}

@MainActor final class MissionControlMonitor {
    private var observer: AXObserver?
    private var pid: Int32?
    private var task: Task<Void, Never>?
    private var revision = 0
    let service: MissionControlService
    private let readSnapshot: @MainActor (Int32, [CGRect]) async -> MissionControlService.Snapshot

    init(readSnapshot: (@MainActor (Int32, [CGRect]) async -> MissionControlService.Snapshot)? = nil) {
        let service = MissionControlService()
        self.service = service
        self.readSnapshot = readSnapshot ?? { pid, screens in
            await service.snapshot(pid: pid, screens: screens)
        }
    }
    var onChange: ((MissionControlService.Snapshot) -> Void)?
    var screens: () -> [CGRect] = { [] }

    func start() {
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { stop(); return }
        guard pid != dock.processIdentifier else { return }
        stop()
        var created: AXObserver?
        guard AXObserverCreate(dock.processIdentifier, missionControlChanged, &created) == .success, let created else { return }
        let app = AXUIElementCreateApplication(dock.processIdentifier)
        let context = Unmanaged.passUnretained(self).toOpaque()
        for name in [kAXCreatedNotification, kAXUIElementDestroyedNotification, kAXSelectedChildrenChangedNotification, kAXFocusedUIElementChangedNotification] {
            AXObserverAddNotification(created, app, name as CFString, context)
        }
        observer = created
        pid = dock.processIdentifier
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
        refresh()
    }

    func stop() {
        revision += 1
        task?.cancel()
        task = nil
        if let observer { CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes) }
        observer = nil
        pid = nil
    }

    func refresh() {
        guard let pid else { return }
        revision += 1
        let current = revision
        task?.cancel()
        // Dock accepts AX subscriptions but does not reliably notify Mission Control
        // entry (notably gesture entry). A serialized, shallow root check is the
        // fallback; full card traversal happens only when the mc root exists.
        task = Task { [weak self] in
            while !Task.isCancelled {
                guard !Task.isCancelled, let self, self.revision == current else { return }
                let snapshot = await self.readSnapshot(pid, self.screens())
                guard !Task.isCancelled, self.revision == current else { return }
                self.onChange?(snapshot)
                try? await Task.sleep(for: .milliseconds(300))
            }
        }
    }
}
