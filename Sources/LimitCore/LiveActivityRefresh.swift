import Foundation

/// When to push content to the Live Activity. The card dims a speed a few seconds after it was sent so a
/// number that has stopped updating can't pass for a live one, which means steady driving (same limit,
/// same speed) has to be re-sent too, or the card dims while everything is fine.
///
/// "Late" and "no GPS" are different: no GPS is sent by the app (it knows within a few seconds), while
/// late is shown by the card itself, which dims a speed `dimAfter` seconds after it was sent when the
/// app's updates stop arriving (the system throttles them, or the app was suspended or killed).
public enum LiveActivityRefresh {
    /// Seconds between sends when nothing has changed. Comfortably inside `dimAfter`.
    public static let heartbeat: TimeInterval = 3
    /// How long after a speed is received the card dims it, on its own, if nothing newer has arrived.
    /// Longer than the heartbeat, or steady driving would dim between sends.
    public static let dimAfter: TimeInterval = 5

    public static func shouldSend(changed: Bool, secondsSinceLastSend: TimeInterval?) -> Bool {
        guard !changed else { return true }
        guard let secondsSinceLastSend else { return true }
        return secondsSinceLastSend >= heartbeat
    }
}
