internal protocol EventEngine: Sendable {
    func append(_ event: VaultEvent) async throws
    func listEvents(for vaultId: VaultID) async throws -> [VaultEvent]
    func events(for vaultId: VaultID) async throws -> [VaultEvent]
}
