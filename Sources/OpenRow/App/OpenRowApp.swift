import AppKit
import SwiftUI

@main struct OpenRowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra("OpenRow", systemImage: "cursorarrow.rays") {
            OpenRowMenu(model: delegate.model)
        }
        .menuBarExtraStyle(.menu)
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) { model.start() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) { model.shutdown() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        model.showSettings()
        return false
    }
}

struct OpenRowMenu: View {
    @Bindable var model: AppModel

    var body: some View {
        Label(model.status, systemImage: model.statusSymbol)
        if !model.message.isEmpty { Text(model.message) }
        Divider()
        Button("Click Mode", systemImage: "cursorarrow.click.2") { model.activate(.click) }
            .disabled(!model.canActivate)
        Button("Scroll Mode", systemImage: "arrow.up.and.down.and.arrow.left.and.right") { model.activate(.scroll) }
            .disabled(!model.canActivate)
        Button(model.preferences.paused ? "Resume" : "Pause", systemImage: "pause.circle.fill") {
            model.setPaused(!model.preferences.paused)
        }
        Divider()
        Button("Settings…", systemImage: "gearshape") { model.showSettings() }
            .keyboardShortcut(",", modifiers: .command)
        Button("Quit OpenRow") { NSApp.terminate(nil) }
            .keyboardShortcut("q", modifiers: .command)
    }
}
