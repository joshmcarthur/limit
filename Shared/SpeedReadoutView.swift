import SwiftUI
import LimitCore

/// The driver's measured GPS speed. Over the limit it gains a caution pill and a "+N over" label, so the
/// state never relies on colour alone. With no fix it shows a dash, never a frozen number.
struct SpeedReadoutView: View {
    let speed: Int?
    let over: OverLimitState
    var size: CGFloat = 112
    var unitFont: Font = .body

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: DesignTokens.space1) {
            Text(speed.map(String.init) ?? "–")
                .font(.system(size: size, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(numberColor)
                .padding(.horizontal, size * 0.14)
                .padding(.vertical, size * 0.04)
                .background {
                    if over.isOver {
                        RoundedRectangle(cornerRadius: DesignTokens.radiusMedium, style: .continuous)
                            .fill(Palette.caution)
                            .transition(.opacity)
                    }
                }
                .contentTransition(.numericText())
            caption
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: over)
        .animation(reduceMotion ? nil : .default, value: speed)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AccessibilityLabels.readout(speed: speed, over: over))
    }

    private var numberColor: Color {
        if over.isOver { return Palette.onCaution }
        return speed == nil ? Palette.inkMuted : Palette.ink
    }

    @ViewBuilder private var caption: some View {
        if case .over(let by) = over {
            Text("+\(by) over").font(unitFont.weight(.semibold)).foregroundStyle(Palette.cautionInk)
        } else if speed == nil {
            Text("No GPS yet").font(unitFont).foregroundStyle(Palette.inkMuted)
        } else {
            Text("km/h").font(unitFont).foregroundStyle(Palette.inkMuted)
        }
    }
}
