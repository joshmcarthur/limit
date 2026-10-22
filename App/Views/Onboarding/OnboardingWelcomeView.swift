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
                           detail: "Limits come from the NZTA National Speed Limit Register. They’re stored on your phone and work offline.")
                FeatureRow(symbol: "speedometer", title: "Your speed",
                           detail: "Your GPS speed is shown next to the speed limit.")
                FeatureRow(symbol: "iphone", title: "On your Lock Screen",
                           detail: "You don’t need the app open. Speed limits show on the Lock Screen and in the Dynamic Island.")
            }
            Spacer(minLength: 0)
            VStack(spacing: DesignTokens.space4) {
                Text("Always obey the posted speed limits and follow the NZ Road Code. Use this app as a guide only.")
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
