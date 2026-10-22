import SwiftUI
import LimitCore

struct AboutView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        List {
            Section {
                Text("Always obey the posted speed limits and follow the NZ Road Code. Use this app as a guide only.")
                    .font(.headline)
                Text("The register can be out of date or differ from the signs on the road, and GPS speed can be a few km/h out.")
                    .font(.body)
                Text("A speed limit is a maximum, not a target. Slow down for the conditions, and set up the app before you drive.")
                    .font(.body)
            }
            Section("Speed limit data") {
                SyncStatusRow(state: model.syncState, retry: model.retrySync)
                Text("The National Speed Limit Register (NSLR) holds New Zealand’s certified speed limits in one place. It’s updated every night, and emergency limits are added soon after they’re set. Temporary limits, like roadworks, aren’t included.")
                    .font(.body)
                Text("School zone limits apply on weekdays during school hours. The register doesn’t have term dates, so they also show during school holidays.")
                    .font(.body)
                Link(destination: Self.registerWebsite) {
                    Label("Search the register online", systemImage: "arrow.up.right.square")
                }
            }
            Section("Attribution") {
                Text("Speed limit data comes from the National Speed Limit Register (NSLR) by Waka Kotahi NZ Transport Agency, licensed under Creative Commons Attribution 4.0 International.")
                    .font(.body)
                Text("We’ve changed the data so it works offline: only limits currently in force are kept, repeated records are merged, and school times are read from the notes. Waka Kotahi doesn’t endorse this app.")
                    .font(.body)
                Link(destination: Self.sourceData) {
                    Label("View the source data", systemImage: "arrow.up.right.square")
                }
                Link(destination: Self.licence) {
                    Label("Read the CC BY 4.0 licence", systemImage: "arrow.up.right.square")
                }
            }
            Section("Privacy") {
                Text("Your location and speed stay on your device. You don’t need an account, and we don’t collect any information.")
                    .font(.body)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// The dataset page the register is downloaded from.
    private static let sourceData = URL(string: "https://opendata-nzta.opendata.arcgis.com/datasets/NZTA::national-speed-limit-register-nslr/about")!
    private static let licence = URL(string: "https://creativecommons.org/licenses/by/4.0/")!

    /// The NSLR web application, where you can look up a speed limit or get a certified copy.
    private static let registerWebsite = URL(string: "https://speedlimits.nzta.govt.nz/")!
}
