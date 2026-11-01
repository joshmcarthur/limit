import Foundation

/// When to push content to the Live Activity.
///
/// The card shows the zone name unless the person asks for their speed. A name changes with the zone, so a
/// speed-only change is not sent, and there is no heartbeat.
///
/// When the card shows speed, a change is sent at once. The system shows that about once a second while the
/// app is active and the screen is awake, and about every 10 seconds otherwise. Steady driving (same limit,
/// same speed) is re-sent on `heartbeat`, inside `dimAfter`, so a live number stays solid across that gap
/// and a stopped app still fades.
///
/// "Late" and "no GPS" are different: no GPS is sent by the app (it knows within a few seconds), while
/// late is shown by the card itself, which dims a speed `dimAfter` seconds after it was sent when the
/// app's updates stop arriving (the system throttles them, or the app was suspended or killed).
public enum LiveActivityRefresh {
    /// Seconds between sends when the card shows speed and nothing has changed. Inside `dimAfter`.
    public static let heartbeat: TimeInterval = 12
    /// How long after a speed is received the card dims it, on its own, if nothing newer has arrived.
    /// Past the ~10 second gap the system uses when the app is not active or the screen is asleep, so a
    /// healthy card stays solid. Longer than the heartbeat, or steady driving would dim between sends.
    public static let dimAfter: TimeInterval = 15

    /// `contentChanged` is any difference in the frame, or in whether the card shows speed.
    /// `speedOnlyChange` means that difference is only the speed and the over-limit state.
    public static func shouldSend(
        contentChanged: Bool,
        speedOnlyChange: Bool,
        showsSpeed: Bool,
        secondsSinceLastSend: TimeInterval?
    ) -> Bool {
        let sendNow = contentChanged && !(speedOnlyChange && !showsSpeed)
        if sendNow { return true }
        guard showsSpeed else { return false }
        guard let secondsSinceLastSend else { return true }
        return secondsSinceLastSend >= heartbeat
    }
}
