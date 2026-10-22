/// VoiceOver strings, taken from the component guidelines.
public enum AccessibilityLabels {
    public static func sign(_ state: SignState) -> String {
        guard let limit = state.limit else { return "Speed limit unknown" }
        return "Speed limit \(limit) kilometres per hour"
    }

    public static func readout(speed: Int?, over: OverLimitState) -> String {
        guard let speed else { return "Your speed unknown, no GPS" }
        if case .over(let by) = over {
            return "Your speed \(speed) kilometres per hour, \(by) over the limit"
        }
        return "Your speed \(speed) kilometres per hour"
    }
}
