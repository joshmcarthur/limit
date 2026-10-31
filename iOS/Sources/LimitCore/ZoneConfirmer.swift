/// Holds the zone the sign is showing and moves to a different one only once enough samples in a row agree
/// on it, so a stray fix near a boundary can't flip the limit. The first match after having none is taken
/// at once.
struct ZoneConfirmer {
    private(set) var current: SpeedLimitMatch?
    private var candidate: SpeedLimitMatch?
    private var agreeing = 0

    mutating func observe(_ raw: SpeedLimitMatch?, confirmations: Int) {
        guard let current else { self.current = raw; return }
        if raw == current { dropCandidate(); return }
        agreeing = raw == candidate ? agreeing + 1 : 1
        candidate = raw
        if agreeing >= max(confirmations, 1) {
            self.current = raw
            dropCandidate()
        }
    }

    /// Forgets everything, for when what was matched no longer means anything (a gap in GPS, a new register).
    mutating func reset() {
        current = nil
        dropCandidate()
    }

    private mutating func dropCandidate() {
        candidate = nil
        agreeing = 0
    }
}
