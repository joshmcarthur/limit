import SwiftUI
import LimitCore

/// The "Show over from" stepper, shared by Settings and onboarding.
struct ToleranceStepper: View {
    @Binding var settings: LimitSettings

    var body: some View {
        Stepper(value: $settings.overTolerance, in: OverLimitEvaluator.toleranceRange) {
            HStack {
                Text("Show “over” from")
                Spacer()
                Text(settings.toleranceLabel).foregroundStyle(Palette.inkMuted).monospacedDigit()
            }
        }
    }

    /// Says what the tolerance is for, and that it isn't an allowance.
    static let footnote = "GPS speed can be a few km/h out, so “over” only shows once you’re past this. It isn’t a speed you can drive at: the limit is the limit."
}
