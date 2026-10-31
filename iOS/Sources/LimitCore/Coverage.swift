import Foundation

/// Where the register has data. It is New Zealand's, so anywhere else a missing limit means "we don't cover
/// this country", not "still looking", and the screen says so.
public enum Coverage {
    private struct Box {
        let south: Double, north: Double, west: Double, east: Double
        func contains(_ c: Coordinate) -> Bool {
            (south...north).contains(c.latitude) && (west...east).contains(c.longitude)
        }
    }

    /// Rough boxes with a margin of a few tens of kilometres, so a coastal road or the sea just off it isn't
    /// called foreign. Not borders: they only decide which words to show when no zone matches.
    private static let boxes = [
        // North, South and Stewart Islands.
        Box(south: -47.8, north: -34.0, west: 165.8, east: 179.3),
        // Chatham Islands, across the date line from the rest.
        Box(south: -44.8, north: -43.4, west: -177.4, east: -175.3),
    ]

    public static func isNewZealand(_ point: Coordinate) -> Bool {
        boxes.contains { $0.contains(point) }
    }

    public static let outsideNewZealandName = "Outside New Zealand"
    public static let outsideNewZealandDetail = "Limit only has New Zealand speed limits. Your speed is still shown."
}
