@testable import LimitCore

extension RegisterStore {
    /// Writes and switches to a copy in one step. Production code always stages, checks and then commits.
    func save(zones: [SpeedZone], metadata: RegisterMetadata) throws {
        try commit(try stage(zones: zones, metadata: metadata))
    }
}
