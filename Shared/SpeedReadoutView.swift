import SwiftUI
import LimitCore

/// The driver's measured GPS speed. Over the limit it gains a caution pill and a "+N over" label, so the
/// state never relies on colour alone. With no fix it shows a dash, never a frozen number.
struct SpeedReadoutView: View {
    let speed: Int?
    let over: OverLimitState
    var size: CGFloat = 112
    var unitFont: Font = .body
    /// When the speed was received (Live Activity only). The number dims by itself `LiveActivityRefresh.dimAfter`
    /// later, so a number that has stopped updating doesn't look live even before the system marks it stale.
    var receivedAt: Date?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: DesignTokens.space1) {
            number
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(numberColor)
                .padding(.horizontal, size * 0.14)
                // The font's line box is much taller than its digits (room for accents and descenders that
                // numbers don't use), which left a big gap above the caption. Digits are about 0.72 of the
                // size tall, so keep the box to that plus a little air, centred on the digits.
                .frame(height: size * 0.8)
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

    @ViewBuilder private var number: some View {
        let font = Font.system(size: size, weight: .heavy, design: .rounded)
        if let receivedAt, let speed, !over.isOver {
            DimmingText(text: String(speed), font: font, color: numberColor, receivedAt: receivedAt)
        } else {
            Text(speed.map(String.init) ?? "–").font(font).monospacedDigit()
        }
    }

    private var numberColor: Color {
        if over.isOver { return Palette.onCaution }
        return speed == nil ? Palette.inkMuted : Palette.ink
    }

    @ViewBuilder private var caption: some View {
        if case .over(let by) = over {
            Text("+\(by) over").font(unitFont.weight(.semibold)).foregroundStyle(Palette.cautionInk)
        } else if speed == nil {
            Text("No GPS").font(unitFont).foregroundStyle(Palette.inkMuted)
        } else {
            Text("km/h").font(unitFont).foregroundStyle(Palette.inkMuted)
        }
    }
}
