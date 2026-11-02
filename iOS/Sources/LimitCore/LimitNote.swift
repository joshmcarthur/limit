/// A note shown when the limit is not a single permanent number, so the driver doesn't take the sign
/// for the whole story. A permanent limit carries none.
public enum LimitNote: String, Codable, Equatable, Sendable {
    case seasonal
    case temporary
    case variable

    public init?(kind: ZoneKind?) {
        switch kind {
        case .seasonal: self = .seasonal
        case .emergency: self = .temporary
        case .variable: self = .variable
        case .permanent, .none: return nil
        }
    }

    public var label: String {
        switch self {
        case .seasonal: return "Seasonal limit, obey the posted signs"
        case .temporary: return "Temporary limit, obey the posted signs"
        case .variable: return "Variable limit, obey the posted signs"
        }
    }

    /// For VoiceOver, after the limit itself.
    public var spoken: String {
        switch self {
        case .seasonal: return "seasonal"
        case .temporary: return "temporary"
        case .variable: return "variable"
        }
    }
}
