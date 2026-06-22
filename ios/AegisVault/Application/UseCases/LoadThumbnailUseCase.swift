import SecureVaultKit

protocol LoadThumbnailUsing: Sendable {
    func execute(objectId: VaultObjectID) async throws -> VaultThumbnail
}

struct LoadThumbnailUseCase: LoadThumbnailUsing {
    private let vaultEngine: any VaultEngine

    init(vaultEngine: any VaultEngine) {
        self.vaultEngine = vaultEngine
    }

    func execute(objectId: VaultObjectID) async throws -> VaultThumbnail {
        try await vaultEngine.loadThumbnail(for: objectId)
    }
}
