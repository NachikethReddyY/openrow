import SwiftUI

struct OnboardingView: View {
    @Bindable var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Label("Set up OpenRow", systemImage: "cursorarrow.rays").font(.title.weight(.semibold))
                Text("Two macOS permissions let OpenRow find controls, recognize your shortcuts, and perform only the action you choose.")
                    .foregroundStyle(.secondary)
                GroupBox {
                    VStack(spacing: 14) {
                        PermissionRow(kind: .accessibility, allowed: model.permissions.accessibility, model: model)
                        Divider()
                        PermissionRow(kind: .inputMonitoring, allowed: model.permissions.inputMonitoring, model: model)
                    }.padding(8)
                }
                Text("Everything stays on this Mac. OpenRow does not record or upload what you type.").font(.callout).foregroundStyle(.secondary)
                if model.permissions.ready {
                    Text("Use \(KeyboardLayout.description(model.preferences.clickShortcut)) to click, or \(KeyboardLayout.description(model.preferences.scrollShortcut)) to scroll. OpenRow stays in your menu bar.")
                }
                HStack {
                    Button("Check Permissions") { model.refreshPermissions(repair: true) }
                    Spacer()
                    Button(model.permissions.ready ? "Done" : "Set Up Later") { model.finishOnboarding() }
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(28)
        }
    }
}
