import Foundation

public enum ZoneCodecError: Error, Equatable {
    case badMagic
    case unsupportedVersion(UInt8)
    case truncated
    case invalid
}

/// A compact binary form of the register for on-device storage, so launching the app doesn't re-parse
/// GeoJSON. Coordinates are stored as Int32 millionths of a degree (about 0.1 m), which matches the
/// precision the download asks for.
///
/// Layout, little endian: `LMTZ`, version u8, zone count u32, then per zone: limit u8, name length u16
/// (0 = none) and UTF-8 bytes, polygon count u32; per polygon: ring count u32 (first is the outer ring);
/// per ring: point count u32 then lat i32, lon i32 for each point.
public enum ZoneCodec {
    static let magic: [UInt8] = Array("LMTZ".utf8)
    static let version: UInt8 = 1
    static let scale = 1_000_000.0

    public static func encode(_ zones: [SpeedZone]) -> Data {
        var out: [UInt8] = magic
        out.append(version)
        put(UInt32(zones.count), to: &out)
        for zone in zones {
            out.append(UInt8(clamping: zone.limit))
            let name = Array((zone.name ?? "").utf8.prefix(Int(UInt16.max)))
            put(UInt16(name.count), to: &out)
            out.append(contentsOf: name)
            put(UInt32(zone.polygons.count), to: &out)
            for polygon in zone.polygons {
                let rings = [polygon.outer] + polygon.holes
                put(UInt32(rings.count), to: &out)
                for ring in rings {
                    put(UInt32(ring.points.count), to: &out)
                    for p in ring.points {
                        put(Int32(clamping: Int((p.latitude * scale).rounded())), to: &out)
                        put(Int32(clamping: Int((p.longitude * scale).rounded())), to: &out)
                    }
                }
            }
        }
        return Data(out)
    }

    public static func decode(_ data: Data) throws -> [SpeedZone] {
        var r = Reader(storage: [UInt8](data))
        guard try r.bytes(4) == magic else { throw ZoneCodecError.badMagic }
        let v = try r.u8()
        guard v == version else { throw ZoneCodecError.unsupportedVersion(v) }

        let zoneCount = Int(try r.u32())
        // Each zone is at least 11 bytes, so a count beyond that is corrupt, not just large.
        guard zoneCount <= r.remaining / 11 else { throw ZoneCodecError.truncated }
        var zones: [SpeedZone] = []
        zones.reserveCapacity(zoneCount)
        for _ in 0..<zoneCount {
            let limit = Int(try r.u8())
            let nameLength = Int(try r.u16())
            let name = nameLength == 0 ? nil : String(decoding: try r.bytes(nameLength), as: UTF8.self)
            let polygonCount = Int(try r.u32())
            guard polygonCount <= r.remaining / 4 else { throw ZoneCodecError.truncated }
            var polygons: [Polygon] = []
            for _ in 0..<polygonCount {
                let ringCount = Int(try r.u32())
                guard ringCount >= 1, ringCount <= r.remaining / 4 else { throw ZoneCodecError.invalid }
                var rings: [Ring] = []
                for _ in 0..<ringCount {
                    let pointCount = Int(try r.u32())
                    guard pointCount <= r.remaining / 8 else { throw ZoneCodecError.truncated }
                    var points: [Coordinate] = []
                    points.reserveCapacity(pointCount)
                    for _ in 0..<pointCount {
                        let lat = Double(try r.i32()) / scale
                        let lon = Double(try r.i32()) / scale
                        points.append(Coordinate(latitude: lat, longitude: lon))
                    }
                    guard let ring = Ring(points: points) else { throw ZoneCodecError.invalid }
                    rings.append(ring)
                }
                polygons.append(Polygon(outer: rings[0], holes: Array(rings.dropFirst())))
            }
            guard let zone = SpeedZone(name: name, limit: limit, polygons: polygons) else { throw ZoneCodecError.invalid }
            zones.append(zone)
        }
        return zones
    }

    // MARK: Bytes

    private static func put(_ value: UInt16, to out: inout [UInt8]) {
        out.append(UInt8(value & 0xFF)); out.append(UInt8(value >> 8))
    }

    private static func put(_ value: UInt32, to out: inout [UInt8]) {
        for shift in stride(from: 0, to: 32, by: 8) { out.append(UInt8((value >> UInt32(shift)) & 0xFF)) }
    }

    private static func put(_ value: Int32, to out: inout [UInt8]) {
        put(UInt32(bitPattern: value), to: &out)
    }

    private struct Reader {
        let storage: [UInt8]
        var offset = 0

        init(storage: [UInt8]) { self.storage = storage }

        var remaining: Int { storage.count - offset }

        mutating func bytes(_ count: Int) throws -> [UInt8] {
            guard count >= 0, count <= remaining else { throw ZoneCodecError.truncated }
            defer { offset += count }
            return Array(storage[offset..<offset + count])
        }

        mutating func u8() throws -> UInt8 { try bytes(1)[0] }

        mutating func u16() throws -> UInt16 {
            let b = try bytes(2)
            return UInt16(b[0]) | UInt16(b[1]) << 8
        }

        mutating func u32() throws -> UInt32 {
            let b = try bytes(4)
            return UInt32(b[0]) | UInt32(b[1]) << 8 | UInt32(b[2]) << 16 | UInt32(b[3]) << 24
        }

        mutating func i32() throws -> Int32 { Int32(bitPattern: try u32()) }
    }
}
