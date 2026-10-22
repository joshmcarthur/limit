import SwiftUI
import LimitCore

struct FeatureRow: View {
    let symbol: String
    let title: String
    let detail: String
    var iconColor: Color = Palette.tint
    var iconSize: CGFloat = 32

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.space4) {
            Image(systemName: symbol)
                .font(.system(size: iconSize * 0.75))
                .foregroundStyle(iconColor)
                .frame(width: iconSize, height: iconSize)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).foregroundStyle(Palette.ink)
                Text(detail).font(.subheadline).foregroundStyle(Palette.inkMuted)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

struct OnboardingPrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Palette.tint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

struct OnboardingSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(.body)
            .tint(Palette.tint)
            .frame(maxWidth: .infinity, minHeight: 44)
    }
}
