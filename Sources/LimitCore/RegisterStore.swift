import Foundation

public struct RegisterMetadata: Codable, Equatable, Sendable {
    /// When the register was last downloaded and verified against the source.
    public var checkedAt: Date
    public var zoneCount: Int
    /// Features the source returned, including any skipped for having no usable limit.
    public var sourceFeatureCount: Int

    public init(checkedAt: Date, zoneCount: Int, sourceFeatureCount: Int) {
        self.checkedAt = checkedAt
        self.zoneCount = zoneCount
        self.sourceFeatureCount = sourceFeatureCount
    }
}

public struct StoredRegister: Sendable {
    public let register: SpeedLimitRegister
    public let metadata: RegisterMetadata
}

/// Keeps the downloaded register in a directory on disk (the app uses Application Support).
public struct RegisterStore: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    private var zonesURL: URL { directory.appendingPathComponent("register.lmtz") }
    private var metadataURL: URL { directory.appendingPathComponent("register.json") }

    public func save(zones: [SpeedZone], metadata: RegisterMetadata) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // Zones first: if we're interrupted between the two writes, the old metadata still describes a
        // valid (if older) register rather than a new one claiming a fresher date.
        try ZoneCodec.encode(zones).write(to: zonesURL, options: .atomic)
        try Self.encoder.encode(metadata).write(to: metadataURL, options: .atomic)
    }

    /// Records a successful check that changed nothing.
    public func updateCheckedAt(_ date: Date) throws {
        guard var metadata = try loadMetadata() else { return }
        metadata.checkedAt = date
        try Self.encoder.encode(metadata).write(to: metadataURL, options: .atomic)
    }

    public func loadMetadata() throws -> RegisterMetadata? {
        guard FileManager.default.fileExists(atPath: metadataURL.path) else { return nil }
        return try Self.decoder.decode(RegisterMetadata.self, from: Data(contentsOf: metadataURL))
    }

    /// Nil when nothing has been downloaded. Throws if the files are damaged; callers should `clear()`.
    public func load() throws -> StoredRegister? {
        guard let metadata = try loadMetadata(), FileManager.default.fileExists(atPath: zonesURL.path) else { return nil }
        let zones = try ZoneCodec.decode(Data(contentsOf: zonesURL))
        return StoredRegister(register: SpeedLimitRegister(zones: zones), metadata: metadata)
    }

    public func clear() throws {
        for url in [zonesURL, metadataURL] where FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    private static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
