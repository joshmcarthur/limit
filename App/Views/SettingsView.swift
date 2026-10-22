import SwiftUI
import LimitCore

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var model = model
        List {
            Section {
                SyncStatusRow(state: model.syncState, retry: model.retrySync)
            }
            Section {
                Toggle("Show on Lock Screen", isOn: $model.settings.showOnLockScreen)
                Stepper(value: $model.settings.overTolerance, in: OverLimitEvaluator.toleranceRange) {
                    HStack {
                        Text("Show “over” from")
                        Spacer()
                        Text(model.settings.toleranceLabel).foregroundStyle(Palette.inkMuted).monospacedDigit()
                    }
                }
            } header: {
                Text("While driving")
            } footer: {
                Text("GPS speed can be a few km/h out, so “over” only shows once you’re past this. It isn’t a speed you can drive at: the limit is the limit.")
            }
            Section {
                NavigationLink("About the data") { AboutView() }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
        }
    }
}
