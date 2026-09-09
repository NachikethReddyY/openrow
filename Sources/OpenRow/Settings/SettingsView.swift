import AppKit
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

enum SettingsPane: String, CaseIterable, Identifiable {
    case general = "General", shortcuts = "Shortcuts", clicking = "Clicking", scrolling = "Scrolling"
    case ignoredApps = "Ignored Apps", about = "About"
    var id: Self { self }
    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .shortcuts: "command"
        case .clicking: "cursorarrow.click.2"
        case .scrolling: "arrow.up.and.down.and.arrow.left.and.right"
        case .ignoredApps: "app.badge"
        case .about: "info.circle"
        }
    }
}

struct SettingsView: View {
    @Bindable var model: AppModel
    @State private var recording: ShortcutMode?
    @State private var ignoredSelection: String?

    var body: some View {
        NavigationSplitView {
            List(SettingsPane.allCases, selection: $model.settingsPane) { pane in
                Label(pane.rawValue, systemImage: pane.symbol).tag(pane)
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 240)
            .navigationTitle("OpenRow")
        } detail: {
            Form {
                switch model.settingsPane {
                case .general: general
                case .shortcuts: shortcuts
                case .clicking: clicking
                case .scrolling: scrolling
                case .ignoredApps: ignoredApps
                case .about: about
                }
            }
            .formStyle(.grouped)
            .frame(maxWidth: 560, maxHeight: .infinity)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(model.settingsPane.rawValue)
        }
        .sheet(item: $recording) { mode in
            ShortcutRecorderSheet(mode: mode, model: model) { recording = nil }
        }
    }

    private func preference<Value>(_ keyPath: WritableKeyPath<UserPreferences, Value>) -> Binding<Value> {
        Binding(get: { model.preferences[keyPath: keyPath] }, set: { value in
            model.updatePreferences { $0[keyPath: keyPath] = value }
        })
    }

    private var general: some View {
        Group {
            Section {
                LabeledContent("Status") {
                    Label(model.status, systemImage: model.statusSymbol)
                        .foregroundStyle(model.permissions.ready && !model.tapFailed ? Color.primary : Color.orange)
                }
                Toggle("Pause OpenRow", isOn: Binding(get: { model.preferences.paused }, set: { model.setPaused($0) }))
                Toggle("Launch at login", isOn: Binding(get: { model.preferences.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
                LabeledContent("Login item", value: model.loginStatus)
                if SMAppService.mainApp.status == .requiresApproval {
                    Button("Open Login Items") { SMAppService.openSystemSettingsLoginItems() }
                }
            }
            Section("Permissions") {
                PermissionRow(kind: .accessibility, allowed: model.permissions.accessibility, model: model)
                PermissionRow(kind: .inputMonitoring, allowed: model.permissions.inputMonitoring, model: model)
                HStack {
                    Button("Check Permissions") { model.refreshPermissions() }
                    Button("Restart Input") { model.refreshPermissions(repair: true) }
                }
            }
            if !model.message.isEmpty {
                Section { Text(model.message).foregroundStyle(.secondary).textSelection(.enabled) }
            }
            Section {
                Button("Show Setup") { model.showOnboarding() }
                Text("Closing Settings leaves OpenRow in your menu bar.").foregroundStyle(.secondary)
            }
        }
    }

    private var shortcuts: some View {
        Group {
            Section("Modes") {
                shortcutRow(.click, shortcut: model.preferences.clickShortcut)
                shortcutRow(.scroll, shortcut: model.preferences.scrollShortcut)
                Button("Restore Default Shortcuts") {
                    model.updatePreferences {
                        $0.clickShortcut = UserPreferences().clickShortcut
                        $0.scrollShortcut = UserPreferences().scrollShortcut
                    }
                }
            }
            Section("Click Mode") {
                LabeledContent("Cancel", value: "Escape")
                LabeledContent("Delete last key", value: "Backspace")
                Text("Hints follow the physical A S D F G H J K L positions and display your keyboard layout’s characters.")
                    .foregroundStyle(.secondary)
            }
            Section("Scroll Mode") {
                LabeledContent("Left / Down / Up / Right", value: "H J K L")
                LabeledContent("Dash", value: "Shift + move")
                LabeledContent("Change region", value: "Tab or 1–9")
                LabeledContent("Cancel", value: "Escape")
            }
        }
    }

    private func shortcutRow(_ mode: ShortcutMode, shortcut: KeyboardShortcut) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(mode.title).fontWeight(.medium)
                Spacer()
                Button("Record…") { recording = mode }
                    .accessibilityLabel("Record \(mode.title) shortcut")
            }
            Text(KeyboardLayout.description(shortcut)).font(.system(.body, design: .monospaced)).foregroundStyle(.secondary)
        }
    }

    private var clicking: some View {
        Group {
            Section("Hints") {
                Picker("Label size", selection: preference(\.hintSize)) {
                    ForEach(HintSize.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                Text("Single, double, and longer hints share the screen. Short hints stay available even with many controls.").foregroundStyle(.secondary)
            }
            Section("Behavior") {
                Text("Type a complete hint to move the pointer and click once. Escape cancels. Controls that move or disappear are never clicked at their old position.")
                Text("Apps with limited accessibility support may expose fewer controls.").foregroundStyle(.secondary)
            }
        }
    }

    private var scrolling: some View {
        Group {
            Section("Speed") {
                LabeledContent("Scroll speed", value: "\(Int(model.preferences.scrollSpeed)) points / second")
                Slider(value: preference(\.scrollSpeed), in: 120...1800, step: 60) { Text("Scroll speed") }
                LabeledContent("Shift dash", value: model.preferences.dashMultiplier.formatted(.number.precision(.fractionLength(1))) + "×")
                Slider(value: preference(\.dashMultiplier), in: 1...8, step: 0.5) { Text("Dash multiplier") }
            }
            Section("Behavior") {
                Text("Hold H, J, K, or L to scroll left, down, up, or right. Release to stop. Hold Shift to dash.")
                Text("Tab cycles visible regions; 1–9 selects a region. The pointer stays in place and the app keeps focus.").foregroundStyle(.secondary)
            }
        }
    }

    private var ignoredApps: some View {
        Group {
            Section {
                Text("OpenRow passes all keys through in these apps.").foregroundStyle(.secondary)
                if model.preferences.ignoredBundleIDs.isEmpty {
                    Text("No ignored apps.").foregroundStyle(.secondary)
                } else {
                    ForEach(model.preferences.ignoredBundleIDs, id: \.self) { bundleID in
                        HStack {
                            VStack(alignment: .leading) {
                                Label(appName(bundleID), systemImage: "app.badge")
                                Text(bundleID).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                            }
                            Spacer()
                            Button("Remove") { model.updatePreferences { $0.ignoredBundleIDs.removeAll { $0 == bundleID } } }
                                .accessibilityLabel("Remove \(appName(bundleID)) from ignored apps")
                        }
                    }
                }
                Button("Add Application…") { addApplication() }
            }
        }
    }

    private func appName(_ bundleID: String) -> String {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)?.deletingPathExtension().lastPathComponent ?? bundleID
    }

    private func addApplication() {
        let panel = NSOpenPanel()
        panel.title = "Ignore an Application"
        panel.prompt = "Add"
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.begin { response in
            guard response == .OK else { return }
            let identifiers = panel.urls.compactMap { Bundle(url: $0)?.bundleIdentifier }
                .filter { $0 != Bundle.main.bundleIdentifier }
            model.updatePreferences { $0.ignoredBundleIDs.append(contentsOf: identifiers) }
        }
    }

    private var about: some View {
        Group {
            Section {
                HStack {
                    Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 40, height: 40).accessibilityHidden(true)
                    Text("OpenRow").font(.title2.weight(.semibold))
                }
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0")
                Text("Keyboard control for your Mac.")
            }
            Section("Privacy") {
                Text("Everything stays on this Mac. OpenRow does not record your typing, capture your screen, use the network, or collect analytics.")
                Text("Accessibility is read only while finding or validating a control or region. Settings are stored locally. Diagnostic logs contain only counts, durations, and status.").foregroundStyle(.secondary)
            }
            Section("Compatibility") {
                Text("macOS 26 or later. Coverage depends on each app’s accessibility support. Secure input and ignored apps are excluded.")
                Text("Local development build. Developer ID signing and notarization have not been performed.").foregroundStyle(.secondary)
            }
        }
    }
}

struct PermissionRow: View {
    let kind: PermissionKind
    let allowed: Bool
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(kind.title, systemImage: kind.symbol).fontWeight(.medium)
                Spacer()
                Label(allowed ? "Ready" : "Not Allowed", systemImage: allowed ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(allowed ? Color.primary : Color.orange)
            }
            Text(kind.explanation).foregroundStyle(.secondary)
            if !allowed {
                HStack {
                    Button("Grant Access") { kind.request(); model.refreshPermissions() }
                        .accessibilityLabel("Grant \(kind.title) access")
                    Button("Open System Settings") { kind.openSettings() }
                        .accessibilityLabel("Open \(kind.title) System Settings")
                }
            }
        }
        .padding(.vertical, 3)
    }
}
