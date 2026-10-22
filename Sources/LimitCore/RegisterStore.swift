import Foundation

public struct RegisterMetadata: Codable, Equatable, Sendable {
    /// When the register was last downloaded and verified against the source.
    public var checkedAt: Date
    public var zoneCount: Int
    /// Features the source returned, including any skipped for having no usable limit.
    public var sourceFeatureCount: Int
    /// The source layer's last-edit time when this copy was downloaded. Nil if it wasn't known, or for a
    /// copy saved before this was recorded; either way the next check downloads again.
    public var sourceEditedAt: Date?

    public init(checkedAt: Date, zoneCount: Int, sourceFeatureCount: Int, sourceEditedAt: Date? = nil) {
        self.checkedAt = checkedAt
        self.zoneCount = zoneCount
        self.sourceFeatureCount = sourceFeatureCount
        self.sourceEditedAt = sourceEditedAt
    }
}

public struct StoredRegister: Sendable {
    public let register: SpeedLimitRegister
    public let metadata: RegisterMetadata
}

/// A new copy written to disk beside the live one, not yet in use. It becomes the live copy only when
/// `RegisterStore.commit` is called; until then the old copy keeps serving.
public struct StagedRegister: Sendable {
    let name: String
    public let metadata: RegisterMetadata
    let checksum: UInt64
}

/// Keeps the downloaded register in a directory on disk (the app uses Application Support).
///
/// Blue-green: each copy lives in its own folder (`gen-<id>`) and a small `current` file names the one in
/// use. A new copy is written to a fresh folder, checked, and only then does `current` move to it (one
/// atomic write). The old folder is deleted after the move. A crash, a cancel or a bad copy therefore
/// leaves the old register exactly as it was, and any folder `current` doesn't name is cleared later.
public struct RegisterStore: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    private var pointerURL: URL { directory.appendingPathComponent("current") }

    private func zonesURL(_ generation: String) -> URL {
        directory.appendingPathComponent(generation).appendingPathComponent("register.lmtz")
    }

    private func metadataURL(_ generation: String) -> URL {
        directory.appendingPathComponent(generation).appendingPathComponent("register.json")
    }

    /// The folder name `current` points at, if it exists on disk.
    var currentGeneration: String? {
        guard let text = try? String(contentsOf: pointerURL, encoding: .utf8) else { return nil }
        let name = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.hasPrefix("gen-"), !name.contains("/"),
              FileManager.default.fileExists(atPath: metadataURL(name).path)
        else { return nil }
        return name
    }

    /// Writes a new copy next to the live one without touching it.
    public func stage(zones: [SpeedZone], metadata: RegisterMetadata) throws -> StagedRegister {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        removeStrayGenerations()
        let name = "gen-\(UUID().uuidString)"
        try FileManager.default.createDirectory(at: directory.appendingPathComponent(name), withIntermediateDirectories: false)
        // Dates are stored to the second (ISO 8601), so keep them that way to read back equal.
        var metadata = metadata
        metadata.checkedAt = Date(timeIntervalSince1970: metadata.checkedAt.timeIntervalSince1970.rounded(.down))
        let encoded = ZoneCodec.encode(zones)
        do {
            try encoded.write(to: zonesURL(name), options: .atomic)
            try Self.encoder.encode(metadata).write(to: metadataURL(name), options: .atomic)
        } catch {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
            throw error
        }
        return StagedRegister(name: name, metadata: metadata, checksum: Checksum.fnv1a64(encoded))
    }

    /// Reads a staged copy back from disk and confirms it is what `stage` meant to write.
    public func verifyWritten(_ staged: StagedRegister) -> Bool {
        guard let data = try? Data(contentsOf: zonesURL(staged.name)), Checksum.fnv1a64(data) == staged.checksum,
              let metadata = try? Self.decoder.decode(
                RegisterMetadata.self, from: Data(contentsOf: metadataURL(staged.name))),
              metadata == staged.metadata
        else { return false }
        return true
    }

    /// Makes a staged copy the live one, then deletes the old copy.
    public func commit(_ staged: StagedRegister) throws {
        try Data(staged.name.utf8).write(to: pointerURL, options: .atomic)
        removeStrayGenerations()
    }

    /// Throws a staged copy away; the live copy is untouched.
    public func discard(_ staged: StagedRegister) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(staged.name))
    }

    public func save(zones: [SpeedZone], metadata: RegisterMetadata) throws {
        try commit(try stage(zones: zones, metadata: metadata))
    }

    /// Records a successful check that changed nothing.
    public func updateCheckedAt(_ date: Date) throws {
        guard let generation = currentGeneration, var metadata = try loadMetadata() else { return }
        metadata.checkedAt = date
        try Self.encoder.encode(metadata).write(to: metadataURL(generation), options: .atomic)
    }

    public func loadMetadata() throws -> RegisterMetadata? {
        guard let generation = currentGeneration else { return nil }
        return try Self.decoder.decode(RegisterMetadata.self, from: Data(contentsOf: metadataURL(generation)))
    }

    /// Nil when nothing has been downloaded. Throws if the files are damaged; callers should `clear()`.
    public func load() throws -> StoredRegister? {
        guard let generation = currentGeneration, let metadata = try loadMetadata() else { return nil }
        let zones = try ZoneCodec.decode(Data(contentsOf: zonesURL(generation)))
        return StoredRegister(register: SpeedLimitRegister(zones: zones), metadata: metadata)
    }

    public func clear() throws {
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        for url in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            try FileManager.default.removeItem(at: url)
        }
    }

    /// Deletes every generation folder (and any stray file) except the live one.
    private func removeStrayGenerations() {
        let keep = currentGeneration
        let urls = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for url in urls where url.lastPathComponent != "current" && url.lastPathComponent != keep {
            try? FileManager.default.removeItem(at: url)
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
