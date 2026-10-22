import SwiftUI
import LimitCore

/// Starts the register download and lets the driver choose Lock Screen behaviour. They can start driving
/// before the download finishes; the limit shows as unknown until it's in.
struct OnboardingReadyView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(spacing: DesignTokens.space6) {
                VStack(spacing: DesignTokens.space2) {
                    Text("Almost ready").font(.title.bold()).foregroundStyle(Palette.ink)
                    Text("The speed limits are downloading. You can start driving straight away, but the limit will be unknown until they’ve finished.")
                        .font(.body)
                        .foregroundStyle(Palette.inkMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, DesignTokens.space8)

                VStack(alignment: .leading, spacing: DesignTokens.space2) {
                    SyncStatusRow(state: model.syncState, retry: model.retrySync)
                        .padding(.horizontal, DesignTokens.space4)
                        .padding(.vertical, DesignTokens.space2)
                        .background(Palette.surface, in: RoundedRectangle(cornerRadius: DesignTokens.radiusMedium, style: .continuous))
                    Text("The app checks for new speed limit data about once a week when you open it.")
                        .font(.footnote).foregroundStyle(Palette.inkMuted).padding(.horizontal, DesignTokens.space4)
                }

                VStack(alignment: .leading, spacing: DesignTokens.space2) {
                    Text("WHILE DRIVING").font(.footnote).foregroundStyle(Palette.inkMuted).padding(.horizontal, DesignTokens.space4)
                    VStack(spacing: 0) {
                        Toggle("Show on Lock Screen", isOn: $model.settings.showOnLockScreen)
                            .frame(minHeight: 52)
                        Divider()
                        Stepper(value: $model.settings.overTolerance, in: OverLimitEvaluator.toleranceRange) {
                            HStack {
                                Text("Show “over” from")
                                Spacer()
                                Text(model.settings.toleranceLabel).foregroundStyle(Palette.inkMuted).monospacedDigit()
                            }
                        }
                        .frame(minHeight: 52)
                    }
                    .padding(.horizontal, DesignTokens.space4)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: DesignTokens.radiusMedium, style: .continuous))
                    Text("GPS speed can be a few km/h out, so “over” only shows once you’re past this. It isn’t a speed you can drive at: the limit is the limit.")
                        .font(.footnote).foregroundStyle(Palette.inkMuted).padding(.horizontal, DesignTokens.space4)
                }

                VStack(spacing: DesignTokens.space3) {
                    Text("You can change these in Settings.")
                        .font(.footnote).foregroundStyle(Palette.inkMuted)
                    OnboardingPrimaryButton(title: "Done", action: model.finishOnboarding)
                }
                .padding(.horizontal, DesignTokens.space8)
            }
            .padding(.horizontal, DesignTokens.space5)
            .padding(.top, 48)
            .padding(.bottom, DesignTokens.space5)
        }
        .task { model.syncRegister() }
    }
}
