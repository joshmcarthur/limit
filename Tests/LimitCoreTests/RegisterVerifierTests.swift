import XCTest
@testable import LimitCore

final class RegisterVerifierTests: XCTestCase {
    private func downloaded(zones: Int, fetched: Int? = nil, expected: Int? = nil) -> DownloadedRegister {
        let ring = Ring(points: [
            Coordinate(latitude: -41, longitude: 174), Coordinate(latitude: -41, longitude: 175),
            Coordinate(latitude: -40, longitude: 175), Coordinate(latitude: -40, longitude: 174),
        ])!
        let zone = SpeedZone(name: nil, limit: 50, polygons: [Polygon(outer: ring)])!
        return DownloadedRegister(zones: Array(repeating: zone, count: zones), sourceFeatureCount: fetched ?? zones,
                                  expectedFeatureCount: expected)
    }

    private func current(_ count: Int) -> RegisterMetadata {
        RegisterMetadata(checkedAt: Date(), zoneCount: count, sourceFeatureCount: count)
    }

    private let policy = RegisterVerificationPolicy(minimumZones: 100)

    func testAcceptsAHealthyDownload() {
        XCTAssertNil(RegisterVerifier.check(downloaded(zones: 1_000, expected: 1_000), current: current(1_000), policy: policy))
    }

    func testThresholdsAreInclusive() {
        XCTAssertNil(RegisterVerifier.check(downloaded(zones: 800), current: current(1_000), policy: policy), "exactly 80%")
        XCTAssertNotNil(RegisterVerifier.check(downloaded(zones: 799), current: current(1_000), policy: policy))
        XCTAssertNil(RegisterVerifier.check(downloaded(zones: 100), current: nil, policy: policy), "exactly the floor")
        XCTAssertNotNil(RegisterVerifier.check(downloaded(zones: 99), current: nil, policy: policy))
        XCTAssertNil(RegisterVerifier.check(downloaded(zones: 990, fetched: 990, expected: 1_000), current: nil, policy: policy), "exactly 99%")
        XCTAssertNotNil(RegisterVerifier.check(downloaded(zones: 989, fetched: 989, expected: 1_000), current: nil, policy: policy))
    }

    func testGrowthIsFine() {
        XCTAssertNil(RegisterVerifier.check(downloaded(zones: 5_000), current: current(1_000), policy: policy))
    }

    func testReasonsAreSpecific() {
        XCTAssertEqual(RegisterVerifier.check(downloaded(zones: 150, fetched: 150, expected: 1_000), current: nil, policy: policy),
                       .incomplete(fetched: 150, expected: 1_000))
        XCTAssertEqual(RegisterVerifier.check(downloaded(zones: 50), current: nil, policy: policy), .tooFewZones(count: 50, minimum: 100))
        XCTAssertEqual(RegisterVerifier.check(downloaded(zones: 200), current: current(1_000), policy: policy),
                       .muchSmaller(count: 200, current: 1_000))
    }

    func testAnEmptyCurrentCopyDoesNotBlockAnything() {
        XCTAssertNil(RegisterVerifier.check(downloaded(zones: 150), current: current(0), policy: policy))
    }

    func testChecksumDetectsAChangedByte() {
        let a = Data([1, 2, 3, 4]), b = Data([1, 2, 3, 5])
        XCTAssertNotEqual(Checksum.fnv1a64(a), Checksum.fnv1a64(b))
        XCTAssertEqual(Checksum.fnv1a64(a), Checksum.fnv1a64(Data([1, 2, 3, 4])))
        XCTAssertEqual(Checksum.fnv1a64(Data()), 0xcbf29ce484222325)
    }
}
