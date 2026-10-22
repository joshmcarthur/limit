import Foundation

/// What sort of limit a record is, from the register's `speedCategoryName`.
public enum ZoneKind: UInt8, Sendable {
    case permanent = 0
    /// Changes under set conditions (school zones, highway variable-speed signs).
    case variable = 1
    /// Applies on certain dates, for example a holiday period.
    case seasonal = 2
    /// The register calls these "Temporary"; they are emergency limits such as a diversion after a closure.
    case emergency = 3

    /// Nil, or anything we don't recognise, counts as permanent: the limit is shown rather than hidden.
    public init(category: String?) {
        switch category?.trimmingCharacters(in: .whitespaces).lowercased() {
        case "variable": self = .variable
        case "seasonal": self = .seasonal
        case "temporary", "emergency": self = .emergency
        default: self = .permanent
        }
    }

    /// Which limit wins where records overlap: the register allows an emergency limit over a seasonal one
    /// and a seasonal one over a permanent or variable one, never permanent over variable.
    public var priority: Int {
        switch self {
        case .emergency: return 3
        case .seasonal: return 2
        case .permanent, .variable: return 1
        }
    }

    /// Limits that apply for a while and then stop, so it's worth telling the driver which one this is.
    public var isTemporaryByNature: Bool { self == .seasonal || self == .emergency }
}

/// Where a record sits relative to the road, from `speedLimitZoneStructureTypeName`.
public enum StructureType: UInt8, Sendable {
    case none = 0
    case overpass = 1
    case underpass = 2
    case intersection = 3

    public init(name: String?) {
        switch name?.trimmingCharacters(in: .whitespaces).lowercased() {
        case "overpass": self = .overpass
        case "underpass": self = .underpass
        case "intersection": self = .intersection
        default: self = .none
        }
    }

    /// A bridge and the road under it cover the same point, and a position can't say which level you're on.
    public var isGradeSeparated: Bool { self == .overpass || self == .underpass }
}

/// The dates a record applies. Days are NZ calendar days and both ends are inclusive.
public struct ActivePeriod: Equatable, Sendable {
    /// First day it applies; nil means from the beginning.
    public let start: Date?
    /// Last day it applies; nil means no end.
    public let end: Date?
    /// A recurring seasonal limit: the same month-and-day window applies every year, whatever year the
    /// record's dates are in.
    public let repeatsYearly: Bool

    public init?(start: Date?, end: Date?, repeatsYearly: Bool = false) {
        guard start != nil || end != nil else { return nil }
        if let start, let end, end < start { return nil }
        // A yearly window needs both ends to know where it starts and stops.
        guard !repeatsYearly || (start != nil && end != nil) else { return nil }
        // Only the NZ calendar day matters, so keep each end at noon on its day. That also means a period
        // read back from storage (which keeps just the day) equals the one that was written.
        self.start = start.map(Self.noon)
        self.end = end.map(Self.noon)
        self.repeatsYearly = repeatsYearly
    }

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = ReducedLimit.timeZone
        return calendar
    }()

    private static func noon(_ date: Date) -> Date {
        let calendar = Self.calendar
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return calendar.date(from: DateComponents(year: parts.year, month: parts.month, day: parts.day, hour: 12)) ?? date
    }

    /// A day as `yyyymmdd` (for example 20211201), the form kept on disk.
    static func pack(_ date: Date) -> Int32 {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return Int32((parts.year ?? 0) * 10_000 + (parts.month ?? 0) * 100 + (parts.day ?? 0))
    }

    static func unpack(_ packed: Int32) -> Date? {
        let value = Int(packed)
        let (year, month, day) = (value / 10_000, value / 100 % 100, value % 100)
        guard (1...9999).contains(year), (1...12).contains(month), (1...31).contains(day) else { return nil }
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))
    }

    public func isActive(at date: Date) -> Bool {
        let calendar = Self.calendar
        if repeatsYearly, let start, let end {
            let (s, e, d) = (monthDay(start, calendar), monthDay(end, calendar), monthDay(date, calendar))
            // Windows that run over New Year (1 December to 30 April) wrap round.
            return s <= e ? (s <= d && d <= e) : (d >= s || d <= e)
        }
        if let start, date < calendar.startOfDay(for: start) { return false }
        if let end, let after = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end)), date >= after {
            return false
        }
        return true
    }

    private func monthDay(_ date: Date, _ calendar: Calendar) -> Int {
        let parts = calendar.dateComponents([.month, .day], from: date)
        return (parts.month ?? 1) * 100 + (parts.day ?? 1)
    }
}
