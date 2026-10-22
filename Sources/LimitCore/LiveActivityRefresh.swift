import Foundation

/// When to push content to the Live Activity. Content is marked stale a few seconds after it's sent so a
/// dead GPS can't leave a frozen number up, which means steady driving (same limit, same speed) has to
/// be re-sent too, or the activity falls back to "No GPS yet" while everything is fine.
public enum LiveActivityRefresh {
    /// Seconds between sends when nothing has changed. Comfortably inside the stale time.
    public static let heartbeat: TimeInterval = 5
    /// How long after a send the content is marked stale.
    public static let staleAfter: TimeInterval = 10

    public static func shouldSend(changed: Bool, secondsSinceLastSend: TimeInterval?) -> Bool {
        guard !changed else { return true }
        guard let secondsSinceLastSend else { return true }
        return secondsSinceLastSend >= heartbeat
    }
}
