import AppKit
import SwiftUI

enum ShortcutMode: String, Identifiable {
    case click, scroll
    var id: Self { self }
    var title: String { self == .click ? "Click Mode" : "Scroll Mode" }
}

struct ShortcutRecorderSheet: View {
    let mode: ShortcutMode
    @Bindable var model: AppModel
    let dismiss: () -> Void
    @State private var error = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Record \(mode.title) Shortcut").font(.title2.weight(.semibold))
            Text("Press a key with Command, Option, or Control. Escape cancels.")
            if !error.isEmpty { Text(error).foregroundStyle(.red).accessibilityLabel(error) }
            HStack { Spacer(); Button("Cancel", action: dismiss).keyboardShortcut(.cancelAction) }
        }
        .padding(24)
        .frame(width: 420)
        .background(ShortcutCapture { event in
            guard model.recordingShortcut else { return }
            if event.keyCode == KeyCode.escape.rawValue { dismiss(); return }
            let shortcut = KeyboardShortcut(keyCode: KeyCode(event.keyCode), modifiers: InputModifiers(flags: event.modifierFlags))
            do {
                try ShortcutValidator.validate(shortcut, otherShortcut: mode == .click ? model.preferences.scrollShortcut : model.preferences.clickShortcut)
                model.updatePreferences {
                    if mode == .click { $0.clickShortcut = shortcut }
                    else { $0.scrollShortcut = shortcut }
                }
                dismiss()
            } catch { self.error = error.localizedDescription }
        })
        .onAppear { model.recordingShortcut = true; model.cancel() }
        .onDisappear { model.recordingShortcut = false; model.cancel() }
    }
}

private struct ShortcutCapture: NSViewRepresentable {
    let receive: (NSEvent) -> Void
    func makeNSView(context: Context) -> CaptureView {
        let view = CaptureView()
        view.receive = receive
        return view
    }
    func updateNSView(_ view: CaptureView, context: Context) { view.receive = receive }
    static func dismantleNSView(_ view: CaptureView, coordinator: ()) { view.stopCapture() }

    final class CaptureView: NSView {
        var receive: ((NSEvent) -> Void)?
        private var monitor: Any?
        func stopCapture() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            receive = nil
        }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, let window = self.window, window.isVisible, event.window === window else { return event }
                self.receive?(event)
                return nil
            }
        }
        isolated deinit { if let monitor { NSEvent.removeMonitor(monitor) } }
    }
}
