import SwiftUI
import LimitCore

/// The main screen: sign, then speed. Nothing here needs a tap to be useful, and it never presents alerts
/// while moving. Dark first, but follows the system appearance.
struct DriveView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var showSettings = false

    private var isLandscape: Bool { verticalSizeClass == .compact }

    var body: some View {
        let state = model.driveState
        VStack(spacing: 0) {
            topBar(state)
            if isLandscape {
                landscapeContent(state)
                syncFooter.padding(.bottom, DesignTokens.space2)
            } else {
                portraitContent(state)
                bottomBar
            }
        }
        .padding(.horizontal, DesignTokens.space5)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.ground.ignoresSafeArea())
        .sheet(isPresented: $showSettings) { NavigationStack { SettingsView() } }
    }

    // MARK: Layout

    private func portraitContent(_ state: DriveState) -> some View {
        VStack(spacing: 40) {
            signBlock(state, diameter: 220)
            SpeedReadoutView(speed: state.snapshot.speed, over: state.snapshot.over, size: 112)
        }
        .frame(maxHeight: .infinity)
    }

    private func landscapeContent(_ state: DriveState) -> some View {
        HStack(spacing: DesignTokens.space6) {
            signBlock(state, diameter: 200).frame(maxWidth: .infinity)
            SpeedReadoutView(speed: state.snapshot.speed, over: state.snapshot.over, size: 140)
                .frame(maxWidth: .infinity)
        }
        .frame(maxHeight: .infinity)
    }

    private func signBlock(_ state: DriveState, diameter: CGFloat) -> some View {
        VStack(spacing: DesignTokens.space4) {
            SpeedSignView(state: state.snapshot.sign, diameter: diameter, note: state.snapshot.limitNote)
            if let note = state.snapshot.limitNote { LimitNoteView(note: note) }
            VStack(spacing: 2) {
                Text(headline(state)).font(.title3.weight(.semibold)).foregroundStyle(Palette.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
                if let line = subheadline(state) { Text(line).font(.footnote).foregroundStyle(Palette.inkMuted) }
            }
            .multilineTextAlignment(.center)
        }
    }

    private func headline(_ state: DriveState) -> String {
        DriveScreenText.headline(isDriving: model.isDriving, access: model.locationAccess, snapshot: state.snapshot)
    }

    private func subheadline(_ state: DriveState) -> String? {
        DriveScreenText.subheadline(isDriving: model.isDriving, access: model.locationAccess, snapshot: state.snapshot)
    }

    // MARK: Bars

    private func topBar(_ state: DriveState) -> some View {
        HStack {
            Label(state.gps.label, systemImage: state.gps == .searching ? "location" : "location.fill")
                .font(.footnote)
                .foregroundStyle(Palette.inkMuted)
            Spacer()
            // Ending a drive is a small control while driving; coming back is a big one once it has ended.
            if isLandscape || model.isDriving { driveButton(compact: true) }
            Button { showSettings = true } label: { Image(systemName: "slider.horizontal.3").font(.title3) }
                .frame(width: 44, height: 44)
                .accessibilityLabel("Settings")
        }
        .tint(Palette.tint)
        .frame(height: 44)
    }

    private var bottomBar: some View {
        VStack(spacing: DesignTokens.space3) {
            if !model.isDriving { driveButton(compact: false) }
            syncFooter
        }
        .padding(.bottom, DesignTokens.space2)
    }

    /// Where the data comes from and when it was last checked, together. Shown in both orientations.
    private var syncFooter: some View {
        VStack(spacing: 4) {
            Text(LimitCore.attribution)
                .font(.footnote)
                .foregroundStyle(Palette.inkMuted)
                .multilineTextAlignment(.center)
            Group {
                let text = FreshnessText.footer(for: model.syncState, now: Date())
                if let symbol = model.syncState.footerSymbol { Label(text, systemImage: symbol) } else { Text(text) }
            }
            .font(.footnote)
            .foregroundStyle(model.syncState.footerColor)
        }
    }

    private func driveButton(compact: Bool) -> some View {
        let title = model.isDriving ? "End drive" : "Start again"
        let action = { model.isDriving ? model.endDrive() : model.beginDrive() }
        return Group {
            if compact {
                Button(title, action: action).font(.headline).frame(minHeight: 44).padding(.horizontal, DesignTokens.space3)
            } else {
                Button(action: action) {
                    Text(title).font(.headline).frame(maxWidth: .infinity).frame(height: 52)
                        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
        .tint(Palette.tint)
        .accessibilityHint(model.isDriving
            ? "Turns off location and removes the Lock Screen card"
            : "Turns location back on")
    }
}
