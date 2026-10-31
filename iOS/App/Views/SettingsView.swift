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
                ToleranceStepper(settings: $model.settings)
            } header: {
                Text("While driving")
            } footer: {
                Text(ToleranceStepper.footnote)
            }
            Section {
                Toggle("Suggest ending my drive", isOn: $model.settings.suggestEndingDrive)
            } footer: {
                Text("When you get out and walk off, Limit asks whether the drive is over. After 15 minutes without moving it ends the drive by itself, so location isn’t left on.")
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
