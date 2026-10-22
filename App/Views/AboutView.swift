import SwiftUI
import LimitCore

struct AboutView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        List {
            Section {
                Text("A guide, not a guarantee. Signs on the road always win.")
                    .font(.headline)
                Text("Register data can be out of date, temporary limits and roadworks aren’t in it, and GPS speed can be a few km/h out.")
                    .font(.body)
            }
            Section("Speed limit data") {
                SyncStatusRow(state: model.syncState, retry: model.syncRegister)
                Text("Contains data from the \(LimitCore.registerName).")
                    .font(.footnote)
                    .foregroundStyle(Palette.inkMuted)
            }
            Section("Privacy") {
                Text("No account. Your location stays on this phone, and speed limits are looked up on the device.")
                    .font(.body)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}
