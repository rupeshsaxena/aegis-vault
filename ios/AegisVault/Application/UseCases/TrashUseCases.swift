import SecureVaultKit

protocol ListTrashObjectsUsing: Sendable {
    func execute() async throws -> [VaultObjectSummary]
}

struct ListTrashObjectsUseCase: ListTrashObjectsUsing {
    private let vaultEngine: any VaultEngine

    init(vaultEngine: any VaultEngine) {
        self.vaultEngine = vaultEngine
    }

    func execute() async throws -> [VaultObjectSummary] {
        try await vaultEngine.listObjects(
            filter: VaultObjectFilter(includeDeleted: true)
        ).filter(\.isDeleted)
    }
}

protocol RestoreFromTrashUsing: Sendable {
    func execute(id: VaultObjectID) async throws
}

struct RestoreFromTrashUseCase: RestoreFromTrashUsing {
    private let vaultEngine: any VaultEngine

    init(vaultEngine: any VaultEngine) {
        self.vaultEngine = vaultEngine
    }

    func execute(id: VaultObjectID) async throws {
        try await vaultEngine.restoreFromTrash(id)
    }
}

protocol PurgeTrashUsing: Sendable {
    func execute() async throws
}

struct PurgeTrashUseCase: PurgeTrashUsing {
    private let vaultEngine: any VaultEngine

    init(vaultEngine: any VaultEngine) {
        self.vaultEngine = vaultEngine
    }

    func execute() async throws {
        try await vaultEngine.purgeTrash()
    }
}

protocol PermanentlyDeleteObjectUsing: Sendable {
    func execute(id: VaultObjectID) async throws
}

struct PermanentlyDeleteObjectUseCase: PermanentlyDeleteObjectUsing {
    private let vaultEngine: any VaultEngine

    init(vaultEngine: any VaultEngine) {
        self.vaultEngine = vaultEngine
    }

    func execute(id: VaultObjectID) async throws {
        try await vaultEngine.permanentlyDeleteObject(id)
    }
}
