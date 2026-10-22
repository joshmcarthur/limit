/// Whether the app may use the phone's location to find the road you're on.
public enum LocationAccess: Equatable, Sendable {
    case notDetermined
    case denied
    /// Approximate location can't say which road you're on, so limits would show as unknown.
    case reduced
    case authorized

    public var isUsable: Bool { self == .authorized }
}

/// The lines under the sign on the driving screen. The register credit isn't one of them: it sits at the
/// bottom, beside when the data was last checked. They depend on whether a drive is running, what
/// location access there is, and whether a limit is showing, so the order of those checks is kept here
/// where it can be tested.
public enum DriveScreenText {
    public static func headline(isDriving: Bool, access: LocationAccess, snapshot: DriveSnapshot) -> String {
        if !isDriving { return "Drive ended" }
        if !access.isUsable { return "Location needed" }
        if let road = snapshot.roadName { return road }
        return snapshot.limit == nil ? "Finding your road…" : "Speed limit"
    }

    /// Nil when a limit is showing: the road name stands on its own.
    public static func subheadline(isDriving: Bool, access: LocationAccess, snapshot: DriveSnapshot) -> String? {
        if !isDriving { return "Location and the Lock Screen card are off." }
        switch access {
        case .denied: return "Turn on location for Limit in Settings"
        case .reduced: return "Turn on Precise Location so Limit can find your road"
        case .notDetermined: return "Allow location to see the limit"
        case .authorized: return snapshot.limit == nil ? "Obey the posted speed limit signs" : nil
        }
    }
}
