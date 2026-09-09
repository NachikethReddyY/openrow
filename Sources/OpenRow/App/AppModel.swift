import AppKit
import Carbon
import Observation
import ServiceManagement

@MainActor @Observable final class AppModel {
    var preferences: UserPreferences
    var permissions = PermissionStatus.read()
    var mode: OpenRowMode = .idle
    var message = ""
    var tapFailed = false
    var loginStatus = LoginItem.description
    var settingsPane: SettingsPane = .general
    var recordingShortcut = false
    private(set) var discovering = false
    @ObservationIgnored private let store: PreferencesStore
    @ObservationIgnored private let accessibility = AccessibilityService()
    @ObservationIgnored private let overlay = OverlayController()
    @ObservationIgnored private var input: GlobalInput!
    @ObservationIgnored private var inputStarted = false
    @ObservationIgnored private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var scrollTimer: DispatchSourceTimer?
    @ObservationIgnored private var scrollValidationInFlight = false
    @ObservationIgnored private var targets: [TargetSnapshot] = []
    @ObservationIgnored private var codes: [HintCode] = []
    @ObservationIgnored private var prefix: [HintKey] = []
    @ObservationIgnored private var selectedRegion = 0
    @ObservationIgnored private var activePID: Int32?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var lastExternalApplication: NSRunningApplication?
    @ObservationIgnored private var settingsWindow: NSWindow?
    @ObservationIgnored private var onboardingWindow: NSWindow?

    init(store: PreferencesStore = PreferencesStore()) {
        self.store = store
        preferences = store.load()
        input = GlobalInput(preferences: preferences) { [weak self] command, epoch in
            guard let self, self.input.accepts(command, epoch: epoch) else { return }
            self.handle(command)
        }
    }

    var status: String {
        if preferences.paused { return "Paused" }
        if tapFailed { return "Needs Attention" }
        if !permissions.ready { return "Permissions Required" }
        if discovering { return "Finding controls…" }
        if mode == .click { return "Click Mode" }
        if mode == .scroll { return "Scroll Mode" }
        return "Ready"
    }

    var statusSymbol: String {
        if preferences.paused { return "pause.circle.fill" }
        return permissions.ready && !tapFailed ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
    }

    var canActivate: Bool { permissions.ready && !preferences.paused && !tapFailed && inputStarted && !recordingShortcut }

    func start() {
        NSApp.setActivationPolicy(.accessory)
        trackFrontmost()
        observe(NSWorkspace.shared.notificationCenter, NSWorkspace.didActivateApplicationNotification) { model in
            model.cancel()
            model.trackFrontmost()
            model.updateRouting()
        }
        observe(.default, NSApplication.didChangeScreenParametersNotification) { model in
            model.cancel()
            model.overlay.rebuild()
        }
        observe(.default, NSApplication.didBecomeActiveNotification) { model in model.refreshPermissions() }
        observe(NSWorkspace.shared.notificationCenter, NSWorkspace.willSleepNotification) { model in model.cancel() }
        observe(NSWorkspace.shared.notificationCenter, NSWorkspace.sessionDidResignActiveNotification) { model in model.cancel() }
        refreshPermissions()
        if !preferences.onboardingCompleted {
            preferences.onboardingCompleted = true
            savePreferences()
            showOnboarding()
        }
    }

    func shutdown() {
        cancel()
        input.stop()
        observers.forEach { $0.0.removeObserver($0.1) }
        observers.removeAll()
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, action: @escaping @MainActor (AppModel) -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { if let self { action(self) } }
        }
        observers.append((center, token))
    }

    private func trackFrontmost() {
        if let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            lastExternalApplication = app
        }
    }

    func refreshPermissions(repair: Bool = false) {
        permissions = .read()
        loginStatus = LoginItem.description
        if repair { tapFailed = false; input.stop(); inputStarted = false }
        if permissions.ready && !inputStarted && !tapFailed {
            inputStarted = input.start()
            tapFailed = !inputStarted
            if tapFailed { message = "Global input could not start. Check permissions, then choose Restart Input." }
        } else if !permissions.ready {
            cancel()
            input.stop()
            inputStarted = false
        }
        updateRouting()
    }

    func updatePreferences(_ update: (inout UserPreferences) -> Void) {
        cancel()
        update(&preferences)
        preferences = preferences.sanitized()
        savePreferences()
        updateRouting()
    }

    private func savePreferences() {
        do { try store.save(preferences) }
        catch { message = "Settings could not be saved. Try again." }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LoginItem.setEnabled(enabled)
            updatePreferences { $0.launchAtLogin = enabled }
            message = ""
        } catch { message = "Launch at login could not be changed: \(error.localizedDescription)" }
        loginStatus = LoginItem.description
    }

    func setPaused(_ paused: Bool) { updatePreferences { $0.paused = paused } }

    private func isAllowed(_ app: NSRunningApplication?) -> Bool {
        guard let app, app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              !app.isTerminated, let bundleID = app.bundleIdentifier,
              !preferences.ignoredBundleIDs.contains(bundleID),
              bundleID != "com.apple.loginwindow" else { return false }
        return true
    }

    private func updateRouting() {
        let frontmost = NSWorkspace.shared.frontmostApplication
        input.configure(mode: mode, enabled: canActivate && isAllowed(frontmost), preferences: preferences)
    }

    func activate(_ requested: OpenRowMode) {
        if mode == requested { cancel(); return }
        cancel()
        guard canActivate, !IsSecureEventInputEnabled() else {
            message = IsSecureEventInputEnabled() ? "OpenRow is unavailable while secure input is enabled." : "Allow both permissions in General, then restart input."
            return
        }
        let frontmost = NSWorkspace.shared.frontmostApplication
        let application = frontmost?.processIdentifier == ProcessInfo.processInfo.processIdentifier ? lastExternalApplication : frontmost
        guard isAllowed(application), let application else {
            message = "Open a supported app that is not on your ignored list."
            return
        }
        // A Settings window must never become a proxy for clicking an unfocused app.
        guard frontmost?.processIdentifier == application.processIdentifier else {
            message = "Return to the app you want to control and use your shortcut."
            return
        }
        mode = requested
        activePID = application.processIdentifier
        discovering = true
        message = ""
        updateRouting()
        overlay.showMessage(requested == .click ? "Finding controls… Esc cancels" : "Finding scroll regions… Esc cancels")
        let currentGeneration = generation
        let pid = application.processIdentifier
        let screens = overlay.displays.map(\.quartzFrame)
        task = Task { [weak self, accessibility] in
            do {
                let result = try await accessibility.discover(pid: pid, mode: requested, screens: screens)
                guard let self, !Task.isCancelled, self.generation == currentGeneration,
                      self.contextIsValid(pid: pid) else { return }
                self.discovering = false
                guard !result.isEmpty else {
                    self.showNotice(requested == .click ? "This app exposed no supported controls." : "This app exposed no scroll regions.")
                    return
                }
                self.targets = result
                if requested == .click {
                    self.codes = try HintAssigner.codes(forCount: result.count)
                    self.drawHints()
                    self.overlay.announce("Click mode. Type a visible hint. Escape cancels.")
                } else {
                    self.overlay.showRegions(result, selected: 0)
                    self.overlay.announce("Scroll mode. H J K L moves, Shift speeds up, Tab changes region, Escape cancels.")
                }
            } catch is CancellationError {
                return
            } catch {
                guard let self, self.generation == currentGeneration else { return }
                self.showNotice(error.localizedDescription)
            }
        }
    }

    private func contextIsValid(pid: Int32) -> Bool {
        canActivate && !IsSecureEventInputEnabled() && NSWorkspace.shared.frontmostApplication?.processIdentifier == pid
            && isAllowed(NSWorkspace.shared.frontmostApplication)
    }

    func cancel() {
        generation += 1
        task?.cancel()
        task = nil
        stopScrolling()
        mode = .idle
        discovering = false
        activePID = nil
        targets.removeAll(keepingCapacity: true)
        codes.removeAll(keepingCapacity: true)
        prefix.removeAll(keepingCapacity: true)
        selectedRegion = 0
        overlay.hide()
        updateRouting()
    }

    private func showNotice(_ text: String) {
        cancel()
        message = text
        overlay.showMessage(text)
        overlay.announce(text)
        let current = generation
        task = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, let self, self.generation == current else { return }
            self.overlay.hide()
        }
    }

    private func handle(_ command: InputCommand) {
        switch command {
        case .activateClick: activate(.click)
        case .activateScroll: activate(.scroll)
        case .cancel: cancel()
        case .tapFailed:
            tapFailed = true
            inputStarted = false
            cancel()
            message = "Input stopped safely. Choose Restart Input in General."
            overlay.announce(message)
        case let .appendHint(key):
            guard mode == .click, !discovering, let length = codes.first?.keys.count, prefix.count < length else { return }
            let candidate = prefix + [key]
            guard codes.contains(where: { $0.keys.starts(with: candidate) }) else { NSSound.beep(); return }
            prefix = candidate
            drawHints()
            if let index = codes.firstIndex(where: { $0.keys == prefix }) { selectTarget(targets[index]) }
        case .deleteHint:
            if !prefix.isEmpty { prefix.removeLast(); drawHints() }
        case let .setScroll(_, pressed, _):
            guard mode == .scroll, !discovering else { return }
            if pressed { startScrolling() }
            else if input.heldScrollState().0.isEmpty { stopScrolling() }
        case .cycleRegion:
            guard mode == .scroll, !targets.isEmpty else { return }
            stopScrolling()
            selectedRegion = (selectedRegion + 1) % targets.count
            overlay.showRegions(targets, selected: selectedRegion)
        case let .selectRegion(index):
            guard mode == .scroll, targets.indices.contains(index) else { return }
            stopScrolling()
            selectedRegion = index
            overlay.showRegions(targets, selected: selectedRegion)
        }
    }

    private func drawHints() { overlay.showHints(targets: targets, codes: codes, prefix: prefix, size: preferences.hintSize) }

    private func selectTarget(_ target: TargetSnapshot) {
        let current = generation
        task = Task { [weak self, accessibility] in
            guard let self else { return }
            let point = await accessibility.revalidate(target, screens: self.overlay.displays.map(\.quartzFrame))
            guard !Task.isCancelled, self.generation == current, self.contextIsValid(pid: target.pid) else { return }
            guard let point else { self.showNotice("That control changed. Activate Click Mode again."); return }
            self.cancel()
            if !PointerActions.click(at: point) { self.message = "The click could not be posted." }
        }
    }

    private func startScrolling() {
        guard scrollTimer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(16), leeway: .milliseconds(2))
        timer.setEventHandler { [weak self] in self?.scrollTick() }
        scrollTimer = timer
        timer.resume()
    }

    private func stopScrolling() {
        scrollTimer?.cancel()
        scrollTimer = nil
    }

    private func scrollTick() {
        guard mode == .scroll, let pid = activePID, contextIsValid(pid: pid) else { cancel(); return }
        guard !input.heldScrollState().0.isEmpty else { stopScrolling(); return }
        guard targets.indices.contains(selectedRegion), !scrollValidationInFlight else { return }
        let target = targets[selectedRegion]
        let current = generation
        scrollValidationInFlight = true
        Task { [weak self, accessibility] in
            guard let self else { return }
            defer { self.scrollValidationInFlight = false }
            let point = await accessibility.revalidate(target, screens: self.overlay.displays.map(\.quartzFrame))
            guard self.generation == current, self.mode == .scroll, self.scrollTimer != nil,
                  self.targets.indices.contains(self.selectedRegion), self.targets[self.selectedRegion].id == target.id,
                  self.contextIsValid(pid: pid) else { return }
            guard let point else { self.showNotice("That scroll region changed. Activate Scroll Mode again."); return }
            let held = self.input.heldScrollState()
            var vector = CGVector.zero
            for (key, direction) in [(KeyCode.h, ScrollDirection.left), (.j, .down), (.k, .up), (.l, .right)] where held.0.contains(key) {
                let part = direction.vector(points: self.preferences.scrollSpeed / 60,
                    dashMultiplier: self.preferences.dashMultiplier, dashed: held.1)
                vector.dx += part.dx
                vector.dy += part.dy
            }
            if vector != .zero { PointerActions.scroll(at: point, vector: vector) }
        }
    }

    func showSettings() {
        cancel()
        if settingsWindow == nil {
            settingsWindow = makeWindow(title: "OpenRow Settings", size: NSSize(width: 780, height: 540),
                minimum: NSSize(width: 680, height: 460), content: SettingsView(model: self))
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        refreshPermissions()
    }

    func showOnboarding() {
        if onboardingWindow == nil {
            onboardingWindow = makeWindow(title: "Set up OpenRow", size: NSSize(width: 660, height: 440),
                minimum: NSSize(width: 600, height: 420), content: OnboardingView(model: self))
        }
        onboardingWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func finishOnboarding() { onboardingWindow?.close() }
}

import SwiftUI

extension AppModel {
    private func makeWindow<Content: View>(title: String, size: NSSize, minimum: NSSize, content: Content) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = title
        window.minSize = minimum
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: content)
        window.center()
        return window
    }
}
