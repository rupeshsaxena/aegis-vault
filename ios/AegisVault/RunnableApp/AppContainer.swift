import Foundation
import SecureVaultKit

// MARK: - Use Case Protocols

protocol CreateVaultUsing: Sendable {
    func execute(name: String, deviceID: DeviceID, unlockMethod: UnlockMethod) async throws -> VaultID
}

protocol ListVaultObjectsUsing: Sendable {
    func execute(filter: VaultObjectFilter) async throws -> [VaultObjectSummary]
}

protocol CreateSecureNoteUsing: Sendable {
    func execute(title: String, notes: String?) async throws -> VaultObjectID
}

protocol GetObjectDetailUsing: Sendable {
    func execute(id: VaultObjectID) async throws -> VaultObjectDetail
}

protocol UpdateSecureNoteUsing: Sendable {
    func execute(id: VaultObjectID, title: String, notes: String?) async throws
}

protocol MoveObjectToTrashUsing: Sendable {
    func execute(id: VaultObjectID) async throws
}

protocol RestoreFromTrashUsing: Sendable {
    func execute(id: VaultObjectID) async throws
}

protocol ImportRecoveryPackageUsing: Sendable {
    func execute(packageURL: URL, recoverySecret: RecoverySecret) async throws -> RecoveryImportResult
}

// MARK: - Use Case Implementations

struct CreateVaultUseCase: CreateVaultUsing {
    private let vaultEngine: any VaultEngine

    init(vaultEngine: any VaultEngine) {
        self.vaultEngine = vaultEngine
    }

    func execute(name: String, deviceID: DeviceID, unlockMethod: UnlockMethod) async throws -> VaultID {
        try await vaultEngine.createVault(
            config: VaultCreationConfig(name: name, deviceID: deviceID, unlockMethod: unlockMethod)
        )
    }
}

struct ListVaultObjectsUseCase: ListVaultObjectsUsing {
    private let vaultEngine: any VaultEngine

    init(vaultEngine: any VaultEngine) {
        self.vaultEngine = vaultEngine
    }

    func execute(filter: VaultObjectFilter) async throws -> [VaultObjectSummary] {
        try await vaultEngine.listObjects(filter: filter)
    }
}

struct CreateSecureNoteUseCase: CreateSecureNoteUsing {
    private let vaultEngine: any VaultEngine

    init(vaultEngine: any VaultEngine) {
        self.vaultEngine = vaultEngine
    }

    func execute(title: String, notes: String?) async throws -> VaultObjectID {
        let draft = VaultObjectDraft(
            type: .secureNote,
            metadata: VaultMetadata(title: title),
            payload: VaultPayload(notes: notes ?? "")
        )
        return try await vaultEngine.createObject(draft)
    }
}

struct GetObjectDetailUseCase: GetObjectDetailUsing {
    private let vaultEngine: any VaultEngine

    init(vaultEngine: any VaultEngine) {
        self.vaultEngine = vaultEngine
    }

    func execute(id: VaultObjectID) async throws -> VaultObjectDetail {
        try await vaultEngine.getObjectDetail(id: id)
    }
}

struct UpdateSecureNoteUseCase: UpdateSecureNoteUsing {
    private let vaultEngine: any VaultEngine

    init(vaultEngine: any VaultEngine) {
        self.vaultEngine = vaultEngine
    }

    func execute(id: VaultObjectID, title: String, notes: String?) async throws {
        let update = VaultObjectUpdate(
            objectId: id,
            metadata: VaultMetadata(title: title),
            payload: VaultPayload(notes: notes)
        )
        _ = try await vaultEngine.updateObject(update)
    }
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

struct RestoreFromTrashUseCase: RestoreFromTrashUsing {
    private let vaultEngine: any VaultEngine

    init(vaultEngine: any VaultEngine) {
        self.vaultEngine = vaultEngine
    }

    func execute(id: VaultObjectID) async throws {
        try await vaultEngine.restoreFromTrash(id)
    }
}

struct ImportRecoveryPackageUseCase: ImportRecoveryPackageUsing {
    private let vaultEngine: any VaultEngine

    init(vaultEngine: any VaultEngine) {
        self.vaultEngine = vaultEngine
    }

    func execute(packageURL: URL, recoverySecret: RecoverySecret) async throws -> RecoveryImportResult {
        try await vaultEngine.importRecoveryPackage(from: packageURL, recoverySecret: recoverySecret)
    }
}

// MARK: - Container

@MainActor
final class AppContainer {
    let vaultEngine: any VaultEngine
    let resolveRootRouteUseCase: any ResolveRootRouteUsing
    let createVaultUseCase: any CreateVaultUsing
    private let listVaultObjectsUseCase: any ListVaultObjectsUsing

    init(vaultEngine: any VaultEngine = VaultEngineFactory.makeSimulatorEngine()) {
        self.vaultEngine = vaultEngine
        self.resolveRootRouteUseCase = ResolveRootRouteUseCase(vaultEngine: vaultEngine)
        self.createVaultUseCase = CreateVaultUseCase(vaultEngine: vaultEngine)
        self.listVaultObjectsUseCase = ListVaultObjectsUseCase(vaultEngine: vaultEngine)
    }

    func makeRootViewModel() -> RootViewModel {
        RootViewModel(resolveRootRouteUseCase: resolveRootRouteUseCase)
    }

    func makeOnboardingViewModel() -> OnboardingViewModel {
        OnboardingViewModel(createVaultUseCase: createVaultUseCase)
    }

    func makeRecoveryImportUseCase() -> any ImportRecoveryPackageUsing {
        ImportRecoveryPackageUseCase(vaultEngine: vaultEngine)
    }

    func makeVaultHomeFlow() -> VaultHomeFlowUseCases {
        VaultHomeFlowUseCases(
            listObjects: listVaultObjectsUseCase,
            searchObjects: SearchVaultObjectsUseCase(vaultEngine: vaultEngine),
            createNote: CreateSecureNoteUseCase(vaultEngine: vaultEngine),
            getDetail: GetObjectDetailUseCase(vaultEngine: vaultEngine),
            updateNote: UpdateSecureNoteUseCase(vaultEngine: vaultEngine),
            createIdentity: CreateIdentityUseCase(vaultEngine: vaultEngine),
            updateIdentity: UpdateIdentityUseCase(vaultEngine: vaultEngine),
            createCard: CreateCardUseCase(vaultEngine: vaultEngine),
            updateCard: UpdateCardUseCase(vaultEngine: vaultEngine),
            importDocument: ImportDocumentUseCase(vaultEngine: vaultEngine),
            loadThumbnail: LoadThumbnailUseCase(vaultEngine: vaultEngine),
            moveToTrash: MoveObjectToTrashUseCase(vaultEngine: vaultEngine),
            restoreFromTrash: RestoreFromTrashUseCase(vaultEngine: vaultEngine)
        )
    }
}
