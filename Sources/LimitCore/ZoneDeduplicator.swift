/// The register lists a zone once per record, and the same zone (same id, same shape) often appears
/// several times. Keeping one of each roughly halves what's stored and searched.
public enum ZoneDeduplicator {
    /// Drops a zone that repeats an earlier one with the same id, limit and geometry. Zones that share an
    /// id but differ in shape (separate parts of one zone) and zones with no id are all kept, in order.
    public static func unique(_ zones: [SpeedZone]) -> [SpeedZone] {
        var seen: [String: [SpeedZone]] = [:]
        var result: [SpeedZone] = []
        result.reserveCapacity(zones.count)
        for zone in zones {
            guard let id = zone.id else { result.append(zone); continue }
            if seen[id, default: []].contains(where: { $0.limit == zone.limit && $0.polygons == zone.polygons }) { continue }
            seen[id, default: []].append(zone)
            result.append(zone)
        }
        return result
    }
}
