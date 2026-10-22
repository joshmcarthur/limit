import Foundation

/// A span of the day, in minutes after midnight, with `start < end`.
public struct TimeWindow: Equatable, Hashable, Sendable {
    public let startMinute: Int
    public let endMinute: Int

    public init?(startMinute: Int, endMinute: Int) {
        guard startMinute >= 0, endMinute <= 24 * 60, startMinute < endMinute else { return nil }
        self.startMinute = startMinute
        self.endMinute = endMinute
    }

    public func contains(minute: Int) -> Bool { minute >= startMinute && minute < endMinute }
}

/// A lower limit that applies to a zone on school days during set windows (a school zone).
/// The register doesn't hold term dates, so every weekday counts as a school day.
public struct ReducedLimit: Equatable, Sendable {
    public let limit: Int
    public let windows: [TimeWindow]

    public init?(limit: Int, windows: [TimeWindow]) {
        guard !windows.isEmpty else { return nil }
        self.limit = limit
        self.windows = windows
    }

    public static let timeZone = TimeZone(identifier: "Pacific/Auckland") ?? .current

    public func isActive(at date: Date) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Self.timeZone
        let parts = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        guard let weekday = parts.weekday, (2...6).contains(weekday) else { return false }  // Monday to Friday
        let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        return windows.contains { $0.contains(minute: minute) }
    }
}

/// Reads the clock times out of the register's free-text "periods of operation" (`speedLimitZoneVarPrdDesc`).
///
/// The text has hundreds of wordings: "08:30 – 9:15am and 2:45 – 3:30pm", "School Days 8.30 to 9.30 am and
/// 2.30 to 3.30 pm", "School morning period starts at 8.25am and ends at 9.00am; …". It also has wordings
/// with no clock time ("35 minutes before the start of school"), which can't be placed on a clock, and
/// highway variable-speed notices. Anything that doesn't yield one or two plain windows returns nil, so
/// the zone just keeps its permanent limit rather than showing a guess.
public enum SchoolPeriodParser {
    private static let time = try! NSRegularExpression(
        pattern: #"(?<![\d.])(\d{1,2})(?:[\:.](\d{2}))?(?![\d\:])\s*(am|pm|a\.m\.|p\.m\.)?(?!\s*(?:min|km|hour|second))"#,
        options: [.caseInsensitive])

    /// Wording that singles out days ("Thursday only", "2.30pm on Wednesdays") means the times differ by
    /// day, which one set of windows can't express.
    private static let dayNames = try! NSRegularExpression(
        pattern: #"\b(mon|tues|wednes|thurs|fri|satur|sun)day"#, options: [.caseInsensitive])

    private struct Token {
        var hour: Int
        var minute: Int
        var isPM: Bool?
    }

    public static func windows(from text: String) -> [TimeWindow]? {
        let ns = text as NSString
        if dayNames.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) != nil { return nil }
        var tokens: [Token] = []
        for match in time.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            let hasMinutes = match.range(at: 2).location != NSNotFound
            let hasMeridiem = match.range(at: 3).location != NSNotFound
            // A bare number ("10 minutes", "40") isn't a time of day.
            guard hasMinutes || hasMeridiem, let hour = Int(ns.substring(with: match.range(at: 1))) else { continue }
            let minute = hasMinutes ? Int(ns.substring(with: match.range(at: 2))) ?? 0 : 0
            guard (1...12).contains(hour) || (13...23).contains(hour) && !hasMeridiem, minute < 60 else { continue }
            let meridiem = hasMeridiem ? ns.substring(with: match.range(at: 3)).lowercased().hasPrefix("p") : nil
            tokens.append(Token(hour: hour, minute: minute, isPM: meridiem))
        }
        guard tokens.count == 2 || tokens.count == 4 else { return nil }

        var windows: [TimeWindow] = []
        for pair in stride(from: 0, to: tokens.count, by: 2) {
            guard let window = window(start: tokens[pair], end: tokens[pair + 1]) else { return nil }
            windows.append(window)
        }
        // Windows must be separate and in day order.
        for (a, b) in zip(windows, windows.dropFirst()) where a.endMinute > b.startMinute { return nil }
        return windows
    }

    private static func window(start: Token, end: Token) -> TimeWindow? {
        guard let endPM = end.isPM ?? (end.hour >= 13 ? true : nil) else { return nil }
        let endMinute = minutes(end, pm: endPM)
        // "8.30 to 9.30 am": the start borrows the end's am/pm, unless that puts it after the end
        // ("11.30 to 12.30 pm" starts in the morning).
        var startMinute = minutes(start, pm: start.isPM ?? endPM)
        if start.isPM == nil, startMinute >= endMinute { startMinute = minutes(start, pm: !endPM) }
        guard let window = TimeWindow(startMinute: startMinute, endMinute: endMinute),
              window.endMinute - window.startMinute <= 3 * 60,
              window.startMinute >= 5 * 60, window.endMinute <= 19 * 60
        else { return nil }
        return window
    }

    private static func minutes(_ token: Token, pm: Bool) -> Int {
        if token.hour >= 13 { return token.hour * 60 + token.minute }
        let hour = token.hour % 12 + (pm ? 12 : 0)
        return hour * 60 + token.minute
    }
}
