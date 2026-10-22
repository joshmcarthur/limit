import Foundation

/// Platform-independent logic for Limit: geometry, the speed limit register,
/// over-limit evaluation and the state shown by every driving surface.
public enum LimitCore {
    public static let registerName = "NZTA National Speed Limit Register"

    /// Sent with every request to the source, so its operators can see who is asking and get in touch.
    public static var userAgent: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        return "Limit-iOS/\(version) (+https://github.com/joshmcarthur/limit)"
    }
}
