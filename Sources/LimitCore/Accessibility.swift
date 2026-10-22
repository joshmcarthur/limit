/// VoiceOver strings, taken from the component guidelines.
public enum AccessibilityLabels {
    public static func sign(_ state: SignState, note: LimitNote? = nil) -> String {
        guard let limit = state.limit else { return "Speed limit unknown" }
        let spoken = "Speed limit \(limit) kilometres per hour"
        return note.map { "\(spoken), \($0.spoken)" } ?? spoken
    }

    public static func readout(speed: Int?, over: OverLimitState) -> String {
        guard let speed else { return "Your speed isn't available, there's no GPS" }
        if case .over(let by) = over {
            return "Your speed is \(speed) kilometres per hour, \(by) over the limit"
        }
        return "Your speed is \(speed) kilometres per hour"
    }
}
