import SecureVaultKit

protocol TrashApplicationServicing: Sendable {
    func listTrash() async throws -> [VaultObjectSummary]
    func restore(id: VaultObjectID) async throws
    func permanentlyDelete(id: VaultObjectID) async throws
    func purgeExpired() async throws
}

struct TrashApplicationService: TrashApplicationServicing {
    private let listUseCase: any ListTrashObjectsUsing
    private let restoreUseCase: any RestoreFromTrashUsing
    private let purgeUseCase: any PurgeTrashUsing
    private let permanentlyDeleteUseCase: any PermanentlyDeleteObjectUsing

    init(
        listUseCase: any ListTrashObjectsUsing,
        restoreUseCase: any RestoreFromTrashUsing,
        purgeUseCase: any PurgeTrashUsing,
        permanentlyDeleteUseCase: any PermanentlyDeleteObjectUsing
    ) {
        self.listUseCase = listUseCase
        self.restoreUseCase = restoreUseCase
        self.purgeUseCase = purgeUseCase
        self.permanentlyDeleteUseCase = permanentlyDeleteUseCase
    }

    func listTrash() async throws -> [VaultObjectSummary] {
        try await listUseCase.execute()
    }

    func restore(id: VaultObjectID) async throws {
        try await restoreUseCase.execute(id: id)
    }

    func permanentlyDelete(id: VaultObjectID) async throws {
        try await permanentlyDeleteUseCase.execute(id: id)
    }

    func purgeExpired() async throws {
        try await purgeUseCase.execute()
    }
}
