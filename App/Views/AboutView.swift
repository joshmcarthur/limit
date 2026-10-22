import SwiftUI
import LimitCore

struct AboutView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        List {
            Section {
                Text("Always obey the posted speed limits and follow the NZ Road Code. Use this app as a guide only.")
                    .font(.headline)
                Text("The register can be out of date, and GPS speed can be a few km/h out.")
                    .font(.body)
            }
            Section("Speed limit data") {
                SyncStatusRow(state: model.syncState, retry: model.syncRegister)
                Text("The National Speed Limit Register (NSLR) holds New Zealand’s certified speed limits in one place. It’s updated every night, and emergency limits are added soon after they’re set. Temporary limits, like roadworks, aren’t included.")
                    .font(.body)
                Text("School zone limits apply on weekdays during school hours. The register doesn’t have term dates, so they also show during school holidays.")
                    .font(.body)
                Link(destination: Self.registerWebsite) {
                    Label("Search the register online", systemImage: "arrow.up.right.square")
                }
                Text("Contains data from the \(LimitCore.registerName).")
                    .font(.footnote)
                    .foregroundStyle(Palette.inkMuted)
            }
            Section("Privacy") {
                Text("Your location and speed stay on your device. You don’t need an account, and we don’t collect any information.")
                    .font(.body)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// The NSLR web application, where you can look up a speed limit or get a certified copy.
    private static let registerWebsite = URL(string: "https://speedlimits.nzta.govt.nz/")!
}
