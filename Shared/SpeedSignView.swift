import SwiftUI
import LimitCore

/// The posted limit drawn as a regulatory sign. Identical in light and dark; never tappable.
struct SpeedSignView: View {
    let state: SignState
    var diameter: CGFloat = 120

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var limit: Int? { state.limit }

    private var isStale: Bool {
        if case .limit(_, let stale) = state { return stale }
        return false
    }

    var body: some View {
        ZStack {
            Circle().fill(Palette.signFace)
            Circle().strokeBorder(
                limit == nil ? Palette.unknown : Palette.signRing,
                lineWidth: CGFloat(SignMetrics.ringWidth(diameter: Double(diameter)))
            )
            numeral
        }
        .frame(width: diameter, height: diameter)
        .overlay(alignment: .topTrailing) {
            if isStale && SignMetrics.showsStaleBadge(diameter: Double(diameter)) { staleBadge }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AccessibilityLabels.sign(state))
    }

    private var numeral: some View {
        let size = CGFloat(SignMetrics.numeralSize(diameter: Double(diameter), limit: limit ?? 0))
        return Text(limit.map(String.init) ?? "–")
            .font(.system(size: size, weight: .bold))
            .monospacedDigit()
            .tracking(-0.02 * size)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(limit == nil ? Palette.unknown : Palette.signInk)
            .contentTransition(.numericText())
            .animation(reduceMotion ? nil : .default, value: state)
    }

    private var staleBadge: some View {
        let size = diameter * 0.3
        return Image(systemName: "exclamationmark")
            .font(.system(size: size * 0.6, weight: .bold))
            .foregroundStyle(Palette.onCaution)
            .frame(width: size, height: size)
            .background(Circle().fill(Palette.caution))
    }
}
