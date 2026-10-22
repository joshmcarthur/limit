import Foundation
import LimitCore

// Downloads the live register once and reports what came back: how many zones, how big, how long it
// takes to load and look up. Run by hand (`swift run RegisterCheck`); the copy goes to data/ (gitignored).

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
}

var stored: StoredRegister?
let load = try seconds { stored = try store.load() }
let size = (try? FileManager.default.attributesOfItem(atPath: directory.appendingPathComponent("register.lmtz").path)[.size] as? Int) ?? 0
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
