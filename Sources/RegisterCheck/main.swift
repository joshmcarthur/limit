import Foundation
import LimitCore

// Downloads the live register once and reports what came back: how many zones, how big, how long it
// takes to load and look up. Run by hand (`swift run RegisterCheck`); the copy goes to data/ (gitignored).

extension URL {
    var fileSizeInBytes: Int? { try? resourceValues(forKeys: [.fileSizeKey]).fileSize }
}

func seconds(_ block: () throws -> Void) rethrows -> Double {
    let start = Date()
    try block()
    return Date().timeIntervalSince(start)
}

let directory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "data/register-check")
let store = RegisterStore(directory: directory)

let started = Date()
let updater = RegisterUpdater(store: store)
let outcome: RegisterUpdateOutcome
do {
    outcome = try await updater.update { progress in
        if let progress { FileHandle.standardError.write(Data("\rdownloading \(Int(progress * 100))%  ".utf8)) }
    }
} catch RegisterSyncError.rejected(let reason) {
    print("\ndownload rejected, nothing was replaced: \(reason)")
    exit(2)
}
FileHandle.standardError.write(Data("\n".utf8))

switch outcome {
case .unchanged(let metadata):
    print("source unchanged since the copy in \(directory.path) (\(metadata.zoneCount) zones); nothing downloaded")
    print("delete the folder to force a download")
case .downloaded(let zones, let metadata):
    print("downloaded in \(String(format: "%.1f", Date().timeIntervalSince(started))) s")
    print("records from source: \(metadata.sourceFeatureCount), zones kept: \(zones.count)")
    print("with a school reduced limit: \(zones.filter { $0.reduced != nil }.count)")
    let limits = Dictionary(grouping: zones, by: \.limit).mapValues(\.count).sorted { $0.key < $1.key }
    print("by limit: " + limits.map { "\($0.key)=\($0.value)" }.joined(separator: " "))
    print("vertices: \(zones.reduce(0) { $0 + $1.polygons.reduce(0) { $0 + $1.outer.points.count + $1.holes.reduce(0) { $0 + $1.points.count } } })")
    print("source last edited: \(metadata.sourceEditedAt.map { "\($0)" } ?? "unknown")")
    report(zones)
}

/// What kinds of record came back, and how often a bridge and the road under it disagree.
func report(_ zones: [SpeedZone]) {
    let now = Date()
    func count(_ test: (SpeedZone) -> Bool) -> Int { zones.filter(test).count }
    print("kinds: permanent \(count { $0.kind == .permanent }), variable \(count { $0.kind == .variable }), "
        + "seasonal \(count { $0.kind == .seasonal }), emergency \(count { $0.kind == .emergency })")
    print("structures: overpass \(count { $0.structure == .overpass }), underpass \(count { $0.structure == .underpass }), "
        + "intersection \(count { $0.structure == .intersection })")
    print("with dates: \(count { $0.period != nil }), repeating yearly: \(count { $0.period?.repeatsYearly == true }), "
        + "not active today: \(count { !$0.isActive(at: now) })")

    // For each bridge, look for an underpass record covering the middle of it.
    let overpasses = zones.filter { $0.structure == .overpass }
    let underpasses = zones.filter { $0.structure == .underpass }
    var covered = 0, same = 0, differ = 0
    for bridge in overpasses {
        let b = bridge.bounds
        let middle = Coordinate(latitude: (b.minLatitude + b.maxLatitude) / 2, longitude: (b.minLongitude + b.maxLongitude) / 2)
        guard bridge.contains(middle) else { continue }
        covered += 1
        let under = underpasses.filter { $0.contains(middle) && $0.isActive(at: now) }
        guard !under.isEmpty else { continue }
        if under.contains(where: { $0.effectiveLimit(at: now) != bridge.effectiveLimit(at: now) }) { differ += 1 } else { same += 1 }
    }
    print("bridges checked: \(covered) of \(overpasses.count); with a road under them at the same limit: \(same), at a different limit: \(differ)")
}

var stored: StoredRegister?
let load = try seconds { stored = try store.load() }
let size = (FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.fileSizeKey])?.compactMap { ($0 as? URL)?.fileSizeInBytes }.max()) ?? 0
print("stored file: \(String(format: "%.1f", Double(size) / 1_048_576)) MB, loaded in \(String(format: "%.2f", load)) s")

guard let register = stored?.register else { exit(1) }
let places: [(String, Double, Double)] = [
    ("Wellington, Cuba St", -41.2926, 174.7757), ("Wellington CBD", -41.2865, 174.7762),
    ("Auckland, Queen St", -36.8485, 174.7633), ("Christchurch, Gloucester St", -43.5314, 172.6358),
    ("SH1 near Otaki", -40.7550, 175.1450), ("Rural, central Otago", -45.0, 169.3),
]
for (name, lat, lon) in places {
    let match = register.lookup(Coordinate(latitude: lat, longitude: lon))
    print("\(name): \(match.map { "\($0.limit) km/h \($0.zoneName ?? "")" } ?? "no zone")")
}

var hits = 0
let lookups = 20_000
let lookupTime = seconds {
    for i in 0..<lookups {
        let point = Coordinate(latitude: -41.3 + Double(i % 100) * 0.0005, longitude: 174.77 + Double(i / 100) * 0.0005)
        if register.lookup(point) != nil { hits += 1 }
    }
}
print("\(lookups) lookups in Wellington: \(String(format: "%.3f", lookupTime)) s (\(String(format: "%.1f", lookupTime / Double(lookups) * 1e6)) µs each), \(hits) matched")
