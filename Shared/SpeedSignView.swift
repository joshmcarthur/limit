import SwiftUI
import LimitCore

/// The posted limit drawn as a regulatory sign. Identical in light and dark; never tappable.
struct SpeedSignView: View {
    let state: SignState
    var diameter: CGFloat = 120
    /// Read out with the limit when it is a seasonal or temporary one.
    var note: LimitNote?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var limit: Int? { state.limit }

    private var isStale: Bool {
        switch state {
        case .limit(_, let stale), .openRoad(let stale): return stale
        case .unknown: return false
        }
    }

    var body: some View {
        ZStack {
            Circle().fill(Palette.signFace)
            Circle().strokeBorder(
                limit == nil ? Palette.unknown : Palette.signRing,
                lineWidth: CGFloat(SignMetrics.ringWidth(diameter: Double(diameter)))
            )
            if state.isOpenRoad { openRoadStroke } else { numeral }
        }
        .frame(width: diameter, height: diameter)
        .overlay(alignment: .topTrailing) {
            if isStale && SignMetrics.showsStaleBadge(diameter: Double(diameter)) { staleBadge }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AccessibilityLabels.sign(state, note: note))
    }

    /// The "no limit" circle-and-diagonal, in the unknown colour so it never reads as a limit.
    private var openRoadStroke: some View {
        let ring = CGFloat(SignMetrics.ringWidth(diameter: Double(diameter)))
        // Runs ring to ring, ending in the middle of the ring so no gap or cap shows.
        return Rectangle()
            .fill(Palette.unknown)
            .frame(width: ring * 0.6, height: diameter - ring)
            .rotationEffect(.degrees(45))
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
