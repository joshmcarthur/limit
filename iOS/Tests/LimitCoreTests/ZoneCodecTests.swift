import XCTest
@testable import LimitCore

final class ZoneCodecTests: XCTestCase {
    private func ring(_ lat: Double, _ lon: Double, _ size: Double) -> Ring {
        Ring(points: [
            Coordinate(latitude: lat, longitude: lon), Coordinate(latitude: lat, longitude: lon + size),
            Coordinate(latitude: lat + size, longitude: lon + size), Coordinate(latitude: lat + size, longitude: lon),
        ])!
    }

    private func sampleZones() -> [SpeedZone] {
        [
            SpeedZone(name: "GLOUCESTER STREET", limit: 30,
                      polygons: [Polygon(outer: ring(-43.53, 172.63, 0.01), holes: [ring(-43.529, 172.631, 0.002)]),
                                 Polygon(outer: ring(-43.60, 172.70, 0.01))])!,
            SpeedZone(name: nil, limit: 100, polygons: [Polygon(outer: ring(-41.2, 174.7, 0.5))])!,
            SpeedZone(name: "TE PAERAHI — Māori ō", limit: 50, polygons: [Polygon(outer: ring(-40.4, 176.6, 0.01))])!,
        ]
    }

    func testRoundTrip() throws {
        let original = sampleZones()
        let decoded = try ZoneCodec.decode(ZoneCodec.encode(original))
        XCTAssertEqual(decoded.count, original.count)
        for (a, b) in zip(original, decoded) {
            XCTAssertEqual(a.limit, b.limit)
            XCTAssertEqual(a.name, b.name)
            XCTAssertEqual(a.polygons.count, b.polygons.count)
            XCTAssertEqual(a.polygons.map { $0.holes.count }, b.polygons.map { $0.holes.count })
            for (pa, pb) in zip(a.polygons, b.polygons) {
                for (x, y) in zip(pa.outer.points, pb.outer.points) {
                    XCTAssertEqual(x.latitude, y.latitude, accuracy: 1e-6)
                    XCTAssertEqual(x.longitude, y.longitude, accuracy: 1e-6)
                }
            }
        }
    }

    func testDecodedZonesStillContainPoints() throws {
        let decoded = try ZoneCodec.decode(ZoneCodec.encode(sampleZones()))
        XCTAssertTrue(decoded[0].contains(Coordinate(latitude: -43.525, longitude: 172.636)))
        XCTAssertFalse(decoded[0].contains(Coordinate(latitude: -43.528, longitude: 172.632)))  // in the hole
        XCTAssertTrue(decoded[1].contains(Coordinate(latitude: -41.0, longitude: 175.0)))
        XCTAssertFalse(decoded[1].contains(Coordinate(latitude: -40.5, longitude: 175.0)))
    }

    func testEmpty() throws {
        XCTAssertEqual(try ZoneCodec.decode(ZoneCodec.encode([])).count, 0)
    }

    func testBadMagicAndVersion() {
        XCTAssertThrowsError(try ZoneCodec.decode(Data("NOPE\u{1}".utf8))) {
            XCTAssertEqual($0 as? ZoneCodecError, .badMagic)
        }
        var data = ZoneCodec.encode([])
        data[4] = 9
        XCTAssertThrowsError(try ZoneCodec.decode(data)) {
            XCTAssertEqual($0 as? ZoneCodecError, .unsupportedVersion(9))
        }
    }

    func testEveryTruncationThrowsRatherThanCrashing() {
        let data = ZoneCodec.encode(sampleZones())
        for length in 0..<data.count {
            XCTAssertThrowsError(try ZoneCodec.decode(data.prefix(length)), "length \(length)")
        }
    }

    func testHugeCountsAreRejected() {
        var data = Data(ZoneCodec.magic)
        data.append(ZoneCodec.version)
        data.append(contentsOf: [0xFF, 0xFF, 0xFF, 0xFF])
        XCTAssertThrowsError(try ZoneCodec.decode(data))
    }
}
