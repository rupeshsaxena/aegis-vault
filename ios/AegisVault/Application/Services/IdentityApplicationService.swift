import SecureVaultKit

protocol IdentityApplicationServicing: Sendable {
    func createIdentity(_ data: IdentityEditorViewData) async throws -> VaultObjectID
    func updateIdentity(existing: VaultObjectDetail, data: IdentityEditorViewData) async throws -> VaultObjectID
    func loadIdentity(id: VaultObjectID) async throws -> VaultObjectDetail
    func moveToTrash(id: VaultObjectID) async throws
    func restore(id: VaultObjectID) async throws
}

struct IdentityApplicationService: IdentityApplicationServicing {
    private let createUseCase: any CreateIdentityUsing
    private let updateUseCase: any UpdateIdentityUsing
    private let detailUseCase: any GetObjectDetailUsing
    private let moveToTrashUseCase: any MoveObjectToTrashUsing
    private let restoreUseCase: any RestoreFromTrashUsing

    init(
        createUseCase: any CreateIdentityUsing,
        updateUseCase: any UpdateIdentityUsing,
        detailUseCase: any GetObjectDetailUsing,
        moveToTrashUseCase: any MoveObjectToTrashUsing,
        restoreUseCase: any RestoreFromTrashUsing
    ) {
        self.createUseCase = createUseCase
        self.updateUseCase = updateUseCase
        self.detailUseCase = detailUseCase
        self.moveToTrashUseCase = moveToTrashUseCase
        self.restoreUseCase = restoreUseCase
    }

    func createIdentity(_ data: IdentityEditorViewData) async throws -> VaultObjectID {
        try await createUseCase.execute(data: data)
    }

    func updateIdentity(existing: VaultObjectDetail, data: IdentityEditorViewData) async throws -> VaultObjectID {
        try await updateUseCase.execute(existing: existing, data: data)
    }

    func loadIdentity(id: VaultObjectID) async throws -> VaultObjectDetail {
        try await detailUseCase.execute(id: id)
    }

    func moveToTrash(id: VaultObjectID) async throws {
        try await moveToTrashUseCase.execute(id: id)
    }

    func restore(id: VaultObjectID) async throws {
        try await restoreUseCase.execute(id: id)
    }
}
