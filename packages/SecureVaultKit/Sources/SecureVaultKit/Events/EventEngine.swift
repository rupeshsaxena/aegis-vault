internal protocol EventEngine: Sendable {
    func append(_ event: VaultEvent) async throws
    func events(for vaultId: VaultID) async throws -> [VaultEvent]
}
