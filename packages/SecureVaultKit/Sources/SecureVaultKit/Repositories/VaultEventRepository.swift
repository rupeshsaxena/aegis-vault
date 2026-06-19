internal protocol VaultEventRepository: Sendable {
    func append(_ event: VaultEvent) async throws
    func list(for vaultId: VaultID) async throws -> [VaultEvent]
    func listPending(for vaultId: VaultID) async throws -> [VaultEvent]
    func events(for objectId: VaultObjectID, in vaultId: VaultID) async throws -> [VaultEvent]
}

internal struct DefaultVaultEventRepository: VaultEventRepository {
    private let eventEngine: any EventEngine

    init(eventEngine: any EventEngine) {
        self.eventEngine = eventEngine
    }

    func append(_ event: VaultEvent) async throws {
        try await eventEngine.append(event)
    }

    func list(for vaultId: VaultID) async throws -> [VaultEvent] {
        try await eventEngine.listEvents(for: vaultId)
    }

    func listPending(for vaultId: VaultID) async throws -> [VaultEvent] {
        try await list(for: vaultId)
    }

    func events(for objectId: VaultObjectID, in vaultId: VaultID) async throws -> [VaultEvent] {
        try await list(for: vaultId).filter { $0.objectId == objectId }
    }
}

internal struct SQLiteVaultEventRepository: VaultEventRepository {
    private let storageEngine: SQLiteStorageEngine

    init(storageEngine: SQLiteStorageEngine) {
        self.storageEngine = storageEngine
    }

    func append(_ event: VaultEvent) async throws {
        try await storageEngine.appendEvent(event)
    }

    func list(for vaultId: VaultID) async throws -> [VaultEvent] {
        try await storageEngine.listPersistedEvents(for: vaultId)
    }

    func listPending(for vaultId: VaultID) async throws -> [VaultEvent] {
        try await list(for: vaultId)
    }

    func events(for objectId: VaultObjectID, in vaultId: VaultID) async throws -> [VaultEvent] {
        try await list(for: vaultId).filter { $0.objectId == objectId }
    }
}
