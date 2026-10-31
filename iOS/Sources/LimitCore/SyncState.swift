import Foundation

/// How fresh the register data is. Drives the SyncStatus row and the onboarding download card.
public enum SyncState: Equatable, Sendable {
    case neverSynced
    /// `progress` is 0...1, or nil when the total is unknown.
    case updating(progress: Double?)
    case upToDate(checkedAt: Date)
    case stale(checkedAt: Date)
    case failed(lastChecked: Date?)

    public static func resting(checkedAt: Date?, now: Date, policy: FreshnessPolicy = .standard) -> SyncState {
        guard let checkedAt else { return .neverSynced }
        switch policy.level(forAge: now.timeIntervalSince(checkedAt)) {
        case .fresh: return .upToDate(checkedAt: checkedAt)
        case .stale, .tooOld: return .stale(checkedAt: checkedAt)
        }
    }
}

/// Copy for freshness: "today, 6:40 am", "yesterday", "3 Oct". Never raw error codes.
public enum FreshnessText {
    private static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    public static func when(_ date: Date, now: Date, calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            let c = calendar.dateComponents([.hour, .minute], from: date)
            let hour = c.hour ?? 0, minute = c.minute ?? 0
            let h12 = hour % 12 == 0 ? 12 : hour % 12
            return "today, \(h12):\(minute < 10 ? "0" : "")\(minute) \(hour < 12 ? "am" : "pm")"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return "yesterday"
        }
        let c = calendar.dateComponents([.day, .month], from: date)
        return "\(c.day ?? 1) \(months[((c.month ?? 1) - 1) % 12])"
    }

    /// Footer on the driving screen.
    public static func footer(for state: SyncState, now: Date, calendar: Calendar = .current) -> String {
        switch state {
        case .upToDate(let at), .stale(let at):
            return "Speed limits checked \(when(at, now: now, calendar: calendar))"
        case .updating:
            return "Updating speed limits…"
        case .failed(let last?):
            return "Speed limits last checked \(when(last, now: now, calendar: calendar))"
        case .failed(nil), .neverSynced:
            return "Speed limits not downloaded yet"
        }
    }

    public struct Row: Equatable, Sendable {
        public var title: String
        public var subtitle: String
    }

    /// Title says the state; subtitle says when and from where.
    public static func row(for state: SyncState, now: Date, calendar: Calendar = .current) -> Row {
        let source = LimitCore.registerName
        switch state {
        case .upToDate(let at):
            return Row(title: "Speed limits up to date", subtitle: "Checked \(when(at, now: now, calendar: calendar)) · \(source)")
        case .updating(let progress):
            let detail = progress.map { "\(Int(($0 * 100).rounded()))% · " } ?? ""
            return Row(title: "Updating speed limits…", subtitle: "\(detail)\(source)")
        case .stale(let at):
            return Row(title: "Speed limits may be out of date",
                       subtitle: "Last updated \(when(at, now: now, calendar: calendar)) · \(source)")
        case .failed(let last):
            let using = last.map { "Still using speed limit data from \(when($0, now: now, calendar: calendar))." } ?? "There's no speed limit data on this phone yet."
            return Row(title: "Couldn’t update the speed limit database", subtitle: using)
        case .neverSynced:
            return Row(title: "Speed limits not downloaded", subtitle: source)
        }
    }
}
