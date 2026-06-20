import SecureVaultKit

protocol MoveObjectToTrashUsing: Sendable {
    func execute(id: VaultObjectID) async throws
}

struct MoveObjectToTrashUseCase: MoveObjectToTrashUsing {
    private let vaultEngine: any VaultEngine

    init(vaultEngine: any VaultEngine) {
        self.vaultEngine = vaultEngine
    }

    func execute(id: VaultObjectID) async throws {
        try await vaultEngine.moveToTrash(id)
    }
}
