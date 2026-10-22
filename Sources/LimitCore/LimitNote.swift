/// A note shown with the limit when it's one that comes and goes, so the driver doesn't take it for
/// the permanent limit. Permanent limits and school zones carry none.
public enum LimitNote: String, Codable, Equatable, Sendable {
    case seasonal
    case temporary

    public init?(kind: ZoneKind?) {
        switch kind {
        case .seasonal: self = .seasonal
        case .emergency: self = .temporary
        case .permanent, .variable, .none: return nil
        }
    }

    public var label: String {
        switch self {
        case .seasonal: return "Seasonal limit, obey the posted signs"
        case .temporary: return "Temporary limit, obey the posted signs"
        }
    }

    /// For VoiceOver, after the limit itself.
    public var spoken: String {
        switch self {
        case .seasonal: return "seasonal"
        case .temporary: return "temporary"
        }
    }
}
