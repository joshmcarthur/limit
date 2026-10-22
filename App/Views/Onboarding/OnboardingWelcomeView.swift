import SwiftUI
import LimitCore

struct OnboardingWelcomeView: View {
    let next: () -> Void

    var body: some View {
        VStack(spacing: DesignTokens.space8) {
            VStack(spacing: DesignTokens.space5) {
                SpeedSignView(state: .limit(50, isStale: false), diameter: 120)
                VStack(spacing: DesignTokens.space2) {
                    Text("Limit").font(.largeTitle.bold()).foregroundStyle(Palette.ink)
                    Text("See the speed limit for the road you’re on, anywhere in Aotearoa New Zealand.")
                        .font(.body)
                        .foregroundStyle(Palette.inkMuted)
                        .multilineTextAlignment(.center)
                }
            }
            VStack(alignment: .leading, spacing: DesignTokens.space6) {
                FeatureRow(symbol: "map", title: "Every road, even offline",
                           detail: "Limits from the NZTA National Speed Limit Register, kept up to date on your phone.")
                FeatureRow(symbol: "speedometer", title: "Your speed, beside the limit",
                           detail: "Measured by GPS. Quietly shows when you’re over, no alarms.")
                FeatureRow(symbol: "iphone", title: "On your Lock Screen",
                           detail: "Follow along in the Dynamic Island without opening the app.")
            }
            Spacer(minLength: 0)
            VStack(spacing: DesignTokens.space4) {
                Text("A guide, not a guarantee. Signs on the road always win.")
                    .font(.footnote)
                    .foregroundStyle(Palette.inkMuted)
                    .multilineTextAlignment(.center)
                OnboardingPrimaryButton(title: "Continue", action: next)
            }
        }
        .padding(.horizontal, DesignTokens.space8)
        .padding(.top, 48)
        .padding(.bottom, DesignTokens.space5)
    }
}
