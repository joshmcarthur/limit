import SwiftUI
import LimitCore

/// Location permission is asked here, parked, never while moving.
struct OnboardingLocationView: View {
    let next: () -> Void
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: DesignTokens.space8) {
            VStack(spacing: DesignTokens.space5) {
                Image(systemName: "location.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Palette.tint)
                    .frame(width: 96, height: 96)
                    .background(Circle().fill(Palette.tint.opacity(0.12)))
                    .accessibilityHidden(true)
                VStack(spacing: DesignTokens.space2) {
                    Text("Allow location").font(.title.bold()).foregroundStyle(Palette.ink)
                    Text("Limit uses your location to find the road you’re on and to measure your speed.")
                        .font(.body)
                        .foregroundStyle(Palette.inkMuted)
                        .multilineTextAlignment(.center)
                }
            }
            VStack(alignment: .leading, spacing: DesignTokens.space6) {
                FeatureRow(symbol: "iphone", title: "Stays on your phone",
                           detail: "You don’t need an account to use this app, and we don’t collect any information. Everything stays on your device.",
                           iconColor: Palette.inkMuted, iconSize: 28)
                FeatureRow(symbol: "checkmark.circle", title: "“While Using the App” is enough",
                           detail: "Once you start driving, the Lock Screen keeps updating until you end it.",
                           iconColor: Palette.inkMuted, iconSize: 28)
                FeatureRow(symbol: "scope", title: "Precise location needed",
                           detail: "Approximate location can’t tell which road you’re on, so the limit will be unknown.",
                           iconColor: Palette.inkMuted, iconSize: 28)
            }
            Spacer(minLength: 0)
            VStack(spacing: DesignTokens.space2) {
                OnboardingPrimaryButton(title: "Continue") {
                    if model.locationAccess == .notDetermined {
                        model.requestLocationAccess()
                    } else {
                        next()
                    }
                }
                OnboardingSecondaryButton(title: "Not now", action: next)
            }
        }
        .padding(.horizontal, DesignTokens.space8)
        .padding(.top, 48)
        .padding(.bottom, DesignTokens.space5)
        // The system prompt answers asynchronously; move on once it has been answered.
        .onChange(of: model.locationAccess) { old, new in
            if old == .notDetermined, new != .notDetermined { next() }
        }
    }
}
