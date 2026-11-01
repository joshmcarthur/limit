import Foundation
import LimitCore

// Downloads the live register once and reports what came back: how many zones, how big, how long it
// takes to load and look up. Run from iOS/ (`swift run RegisterCheck ../data/register-check`); the copy
// goes to data/ at the repo root (gitignored).
//
// The same copy can be queried the way the app looks a point up, or written out as GeoJSON:
//   --lookup lat,lon
//   --along lat,lon lat,lon [--step 200]
//   --export file.geojson [--bbox minLat,minLon,maxLat,maxLon]

extension URL {
    var fileSizeInBytes: Int? { try? resourceValues(forKeys: [.fileSizeKey]).fileSize }
}

func seconds(_ block: () throws -> Void) rethrows -> Double {
    let start = Date()
    try block()
    return Date().timeIntervalSince(start)
}

let options = CheckOptions.parse()
let directory = URL(fileURLWithPath: options.directory)
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
    // A lookup still has the copy the app would keep. The no-flag report stops here, as before.
    guard options.wantsQuery, let zones = try? store.loadZones() else { exit(2) }
    print("using the copy still in \(directory.path)")
    try query(zones, options)
    exit(0)
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
    if !options.wantsQuery { report(zones) }
}

if options.wantsQuery {
    guard let zones = try store.loadZones() else {
        fputs("no register in \(directory.path)\n", stderr)
        exit(1)
    }
    try query(zones, options)
    exit(0)
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
    // The register has no urban zone for Freshfields Place, so it falls to the default; Steyne Ave is inside one.
    ("Plimmerton, Freshfields Place", -41.0767268, 174.8708714), ("Plimmerton, Steyne Ave", -41.0795, 174.8667),
]
for (name, lat, lon) in places {
    let match = register.lookup(Coordinate(latitude: lat, longitude: lon))
    print("\(name): \(match.map { "\($0.limit) km/h \($0.zoneName ?? "")\($0.isDefaultArea ? " (default area, shown as open road)" : "")" } ?? "no zone")")
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

struct CheckOptions {
    var directory = "../data/register-check"
    var lookups: [Coordinate] = []
    var along: (Coordinate, Coordinate)?
    var stepMetres = 200.0
    var exportPath: String?
    var bbox: BoundingBox?

    var wantsQuery: Bool { !lookups.isEmpty || along != nil || exportPath != nil }

    static func parse() -> CheckOptions {
        var options = CheckOptions()
        var args = Array(CommandLine.arguments.dropFirst())
        var sawDirectory = false
        func take(_ flag: String) -> String {
            guard !args.isEmpty else { fail("missing value for \(flag)") }
            return args.removeFirst()
        }
        while !args.isEmpty {
            let arg = args.removeFirst()
            switch arg {
            case "--lookup":
                options.lookups.append(coordinate(take(arg), flag: arg))
            case "--along":
                let start = coordinate(take(arg), flag: arg)
                let end = coordinate(take(arg), flag: arg)
                options.along = (start, end)
            case "--step":
                guard let metres = Double(take(arg)), metres > 0 else { fail("--step needs a distance in metres") }
                options.stepMetres = metres
            case "--export":
                options.exportPath = take(arg)
            case "--bbox":
                options.bbox = box(take(arg))
            case "--help", "-h":
                print(usage)
                exit(0)
            default:
                if arg.hasPrefix("-") { fail("unknown flag \(arg)") }
                if sawDirectory { fail("unexpected argument \(arg)") }
                options.directory = arg
                sawDirectory = true
            }
        }
        return options
    }
}

func query(_ zones: [SpeedZone], _ options: CheckOptions) throws {
    let register = SpeedLimitRegister(zones: zones)
    for point in options.lookups { print(line(register, point)) }
    if let (start, end) = options.along {
        let points = samples(from: start, to: end, stepMetres: options.stepMetres)
        print("along \(format(start)) to \(format(end)), every \(Int(options.stepMetres)) m, \(points.count) points")
        for point in points { print(line(register, point)) }
    }
    if let path = options.exportPath {
        let chosen = zones.filter { zone in
            guard let bbox = options.bbox else { return true }
            return overlaps(zone.bounds, bbox)
        }
        let data = try JSONSerialization.data(withJSONObject: featureCollection(chosen))
        try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        print("exported \(chosen.count) zones to \(path)")
    }
}

func line(_ register: SpeedLimitRegister, _ point: Coordinate) -> String {
    guard let match = register.lookup(point) else { return "\(format(point)): no zone" }
    let name = match.zoneName ?? "(no name)"
    let area = match.isDefaultArea ? " default-area" : ""
    return "\(format(point)): \(match.limit) \(name) \(kindName(match.kind))\(area)"
}

func format(_ point: Coordinate) -> String {
    String(format: "%.5f,%.5f", point.latitude, point.longitude)
}

func samples(from start: Coordinate, to end: Coordinate, stepMetres: Double) -> [Coordinate] {
    let meanLat = (start.latitude + end.latitude) / 2 * .pi / 180
    let metresPerDegree = 111_320.0
    let north = (end.latitude - start.latitude) * metresPerDegree
    let east = (end.longitude - start.longitude) * metresPerDegree * cos(meanLat)
    let length = hypot(north, east)
    let steps = max(1, Int((length / stepMetres).rounded(.up)))
    return (0...steps).map { i in
        let t = Double(i) / Double(steps)
        return Coordinate(
            latitude: start.latitude + (end.latitude - start.latitude) * t,
            longitude: start.longitude + (end.longitude - start.longitude) * t
        )
    }
}

func overlaps(_ zone: BoundingBox, _ box: BoundingBox) -> Bool {
    zone.maxLatitude >= box.minLatitude && zone.minLatitude <= box.maxLatitude
        && zone.maxLongitude >= box.minLongitude && zone.minLongitude <= box.maxLongitude
}

func featureCollection(_ zones: [SpeedZone]) -> [String: Any] {
    ["type": "FeatureCollection", "features": zones.map(feature)]
}

func feature(_ zone: SpeedZone) -> [String: Any] {
    var properties: [String: Any] = [
        "limit": zone.limit,
        "kind": kindName(zone.kind),
        "structure": structureName(zone.structure),
    ]
    if let name = zone.name { properties["name"] = name }
    let type: String
    let coordinates: Any
    if zone.polygons.count == 1 {
        type = "Polygon"
        coordinates = rings(zone.polygons[0])
    } else {
        type = "MultiPolygon"
        coordinates = zone.polygons.map(rings)
    }
    return [
        "type": "Feature",
        "properties": properties,
        "geometry": ["type": type, "coordinates": coordinates],
    ]
}

func rings(_ polygon: Polygon) -> [[[Double]]] {
    ([polygon.outer] + polygon.holes).map { ring in ring.points.map { [$0.longitude, $0.latitude] } }
}

func kindName(_ kind: ZoneKind) -> String {
    switch kind {
    case .permanent: return "permanent"
    case .variable: return "variable"
    case .seasonal: return "seasonal"
    case .emergency: return "emergency"
    }
}

func structureName(_ structure: StructureType) -> String {
    switch structure {
    case .none: return "none"
    case .overpass: return "overpass"
    case .underpass: return "underpass"
    case .intersection: return "intersection"
    }
}

func coordinate(_ text: String, flag: String) -> Coordinate {
    let parts = text.split(separator: ",").map { Double($0.trimmingCharacters(in: .whitespaces)) }
    guard parts.count == 2, let latitude = parts[0], let longitude = parts[1] else { fail("\(flag) needs lat,lon") }
    return Coordinate(latitude: latitude, longitude: longitude)
}

func box(_ text: String) -> BoundingBox {
    let parts = text.split(separator: ",").map { Double($0.trimmingCharacters(in: .whitespaces)) }
    guard parts.count == 4, let minLat = parts[0], let minLon = parts[1], let maxLat = parts[2], let maxLon = parts[3] else {
        fail("--bbox needs minLat,minLon,maxLat,maxLon")
    }
    return BoundingBox(minLatitude: minLat, maxLatitude: maxLat, minLongitude: minLon, maxLongitude: maxLon)
}

let usage = """
usage: RegisterCheck [directory] [--lookup lat,lon] [--along lat,lon lat,lon] [--step metres] [--export file.geojson] [--bbox minLat,minLon,maxLat,maxLon]
"""

func fail(_ message: String) -> Never {
    fputs("\(message)\n\(usage)\n", stderr)
    exit(1)
}
