import Foundation
import SecureVaultKit

@MainActor
final class AppContainer {
    static let storageDirectoryName = "AegisVault"

    private let vaultEngine: any VaultEngine
    let createVaultUseCase: any CreateVaultUsing
    let unlockVaultUseCase: any UnlockVaultUsing
    let lockVaultUseCase: any LockVaultUsing
    let searchVaultUseCase: any SearchVaultUsing
    let listVaultObjectsUseCase: any ListVaultObjectsUsing
    let getObjectDetailUseCase: any GetObjectDetailUsing
    let moveObjectToTrashUseCase: any MoveObjectToTrashUsing
    let createSecureNoteUseCase: any CreateSecureNoteUsing
    let updateSecureNoteUseCase: any UpdateSecureNoteUsing
    let createIdentityUseCase: any CreateIdentityUsing
    let updateIdentityUseCase: any UpdateIdentityUsing
    let createCardUseCase: any CreateCardUsing
    let updateCardUseCase: any UpdateCardUsing
    let importDocumentUseCase: any ImportDocumentUsing
    let loadThumbnailUseCase: any LoadThumbnailUsing
    let listTrashObjectsUseCase: any ListTrashObjectsUsing
    let restoreFromTrashUseCase: any RestoreFromTrashUsing
    let purgeTrashUseCase: any PurgeTrashUsing
    let permanentlyDeleteObjectUseCase: any PermanentlyDeleteObjectUsing
    let getSecurityStatusUseCase: any GetSecurityStatusUsing
    let updateAutoLockPolicyUseCase: any UpdateAutoLockPolicyUsing
    let listTrustedDevicesUseCase: any ListTrustedDevicesUsing
    let getRecoveryStatusUseCase: any GetRecoveryStatusUsing
    let exportRecoveryPackageUseCase: any ExportRecoveryPackageUsing
    let resolveAppRouteUseCase: any ResolveAppRouteUsing
    let secureNoteService: any SecureNoteApplicationServicing
    let identityService: any IdentityApplicationServicing
    let cardService: any CardApplicationServicing
    let documentService: any DocumentApplicationServicing
    let trashService: any TrashApplicationServicing

    init(engineFactory: @Sendable () throws -> any VaultEngine) throws {
        let engine = try engineFactory()
        let createVaultUseCase = CreateVaultUseCase(vaultEngine: engine)
        let unlockVaultUseCase = UnlockVaultUseCase(vaultEngine: engine)
        let lockVaultUseCase = LockVaultUseCase(vaultEngine: engine)
        let searchVaultUseCase = SearchVaultUseCase(vaultEngine: engine)
        let listVaultObjectsUseCase = ListVaultObjectsUseCase(vaultEngine: engine)
        let getObjectDetailUseCase = GetObjectDetailUseCase(vaultEngine: engine)
        let moveObjectToTrashUseCase = MoveObjectToTrashUseCase(vaultEngine: engine)
        let createSecureNoteUseCase = CreateSecureNoteUseCase(vaultEngine: engine)
        let updateSecureNoteUseCase = UpdateSecureNoteUseCase(vaultEngine: engine)
        let createIdentityUseCase = CreateIdentityUseCase(vaultEngine: engine)
        let updateIdentityUseCase = UpdateIdentityUseCase(vaultEngine: engine)
        let createCardUseCase = CreateCardUseCase(vaultEngine: engine)
        let updateCardUseCase = UpdateCardUseCase(vaultEngine: engine)
        let importDocumentUseCase = ImportDocumentUseCase(vaultEngine: engine)
        let loadThumbnailUseCase = LoadThumbnailUseCase(vaultEngine: engine)
        let listTrashObjectsUseCase = ListTrashObjectsUseCase(vaultEngine: engine)
        let restoreFromTrashUseCase = RestoreFromTrashUseCase(vaultEngine: engine)
        let purgeTrashUseCase = PurgeTrashUseCase(vaultEngine: engine)
        let permanentlyDeleteObjectUseCase = PermanentlyDeleteObjectUseCase(vaultEngine: engine)
        let getSecurityStatusUseCase = GetSecurityStatusUseCase(vaultEngine: engine)
        let updateAutoLockPolicyUseCase = UpdateAutoLockPolicyUseCase(vaultEngine: engine)
        let listTrustedDevicesUseCase = ListTrustedDevicesUseCase(vaultEngine: engine)
        let getRecoveryStatusUseCase = GetRecoveryStatusUseCase(vaultEngine: engine)
        let exportRecoveryPackageUseCase = ExportRecoveryPackageUseCase(vaultEngine: engine)
        let resolveAppRouteUseCase = ResolveAppRouteUseCase(vaultEngine: engine)

        self.vaultEngine = engine
        self.createVaultUseCase = createVaultUseCase
        self.unlockVaultUseCase = unlockVaultUseCase
        self.lockVaultUseCase = lockVaultUseCase
        self.searchVaultUseCase = searchVaultUseCase
        self.listVaultObjectsUseCase = listVaultObjectsUseCase
        self.getObjectDetailUseCase = getObjectDetailUseCase
        self.moveObjectToTrashUseCase = moveObjectToTrashUseCase
        self.createSecureNoteUseCase = createSecureNoteUseCase
        self.updateSecureNoteUseCase = updateSecureNoteUseCase
        self.createIdentityUseCase = createIdentityUseCase
        self.updateIdentityUseCase = updateIdentityUseCase
        self.createCardUseCase = createCardUseCase
        self.updateCardUseCase = updateCardUseCase
        self.importDocumentUseCase = importDocumentUseCase
        self.loadThumbnailUseCase = loadThumbnailUseCase
        self.listTrashObjectsUseCase = listTrashObjectsUseCase
        self.restoreFromTrashUseCase = restoreFromTrashUseCase
        self.purgeTrashUseCase = purgeTrashUseCase
        self.permanentlyDeleteObjectUseCase = permanentlyDeleteObjectUseCase
        self.getSecurityStatusUseCase = getSecurityStatusUseCase
        self.updateAutoLockPolicyUseCase = updateAutoLockPolicyUseCase
        self.listTrustedDevicesUseCase = listTrustedDevicesUseCase
        self.getRecoveryStatusUseCase = getRecoveryStatusUseCase
        self.exportRecoveryPackageUseCase = exportRecoveryPackageUseCase
        self.resolveAppRouteUseCase = resolveAppRouteUseCase
        self.secureNoteService = SecureNoteApplicationService(
            createUseCase: createSecureNoteUseCase,
            updateUseCase: updateSecureNoteUseCase,
            detailUseCase: getObjectDetailUseCase,
            moveToTrashUseCase: moveObjectToTrashUseCase,
            restoreUseCase: restoreFromTrashUseCase
        )
        self.identityService = IdentityApplicationService(
            createUseCase: createIdentityUseCase,
            updateUseCase: updateIdentityUseCase,
            detailUseCase: getObjectDetailUseCase,
            moveToTrashUseCase: moveObjectToTrashUseCase,
            restoreUseCase: restoreFromTrashUseCase
        )
        self.cardService = CardApplicationService(
            createUseCase: createCardUseCase,
            updateUseCase: updateCardUseCase,
            detailUseCase: getObjectDetailUseCase,
            moveToTrashUseCase: moveObjectToTrashUseCase,
            restoreUseCase: restoreFromTrashUseCase
        )
        self.documentService = DocumentApplicationService(
            importUseCase: importDocumentUseCase,
            detailUseCase: getObjectDetailUseCase,
            thumbnailUseCase: loadThumbnailUseCase,
            moveToTrashUseCase: moveObjectToTrashUseCase,
            restoreUseCase: restoreFromTrashUseCase
        )
        self.trashService = TrashApplicationService(
            listUseCase: listTrashObjectsUseCase,
            restoreUseCase: restoreFromTrashUseCase,
            purgeUseCase: purgeTrashUseCase,
            permanentlyDeleteUseCase: permanentlyDeleteObjectUseCase
        )
    }

    static func makeDefault() throws -> AppContainer {
        let storageURL = try persistentStorageURL()
        return try AppContainer {
            try VaultEngineFactory.makePersistentLocalEngine(
                storageURL: storageURL
            )
        }
    }

    static func persistentStorageURL(
        fileManager: FileManager = .default
    ) throws -> URL {
        let applicationSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let storageURL = applicationSupportURL
            .appendingPathComponent(storageDirectoryName, isDirectory: true)
        try fileManager.createDirectory(at: storageURL, withIntermediateDirectories: true)
        return storageURL
    }

    func makeOnboardingViewModel() -> OnboardingViewModel {
        OnboardingViewModel(createVaultUseCase: createVaultUseCase)
    }

    func makeUnlockViewModel() -> UnlockViewModel {
        UnlockViewModel(unlockVaultUseCase: unlockVaultUseCase)
    }

    func makeVaultHomeViewModel() -> VaultHomeViewModel {
        VaultHomeViewModel(
            listVaultObjectsUseCase: listVaultObjectsUseCase,
            searchVaultUseCase: searchVaultUseCase,
            lockVaultUseCase: lockVaultUseCase,
            loadThumbnailUseCase: loadThumbnailUseCase
        )
    }

    func makeObjectDetailViewModel() -> ObjectDetailViewModel {
        ObjectDetailViewModel(
            getObjectDetailUseCase: getObjectDetailUseCase,
            moveObjectToTrashUseCase: moveObjectToTrashUseCase,
            loadThumbnailUseCase: loadThumbnailUseCase
        )
    }

    func makeIdentityEditorViewModel() -> IdentityEditorViewModel {
        IdentityEditorViewModel(
            identityService: identityService
        )
    }

    func makeSecureNoteEditorViewModel() -> SecureNoteEditorViewModel {
        SecureNoteEditorViewModel(
            secureNoteService: secureNoteService
        )
    }

    func makeCardEditorViewModel() -> CardEditorViewModel {
        CardEditorViewModel(
            cardService: cardService
        )
    }

    func makeDocumentImportViewModel() -> DocumentImportViewModel {
        DocumentImportViewModel(documentService: documentService)
    }

    func makeTrashViewModel() -> TrashViewModel {
        TrashViewModel(
            trashService: trashService
        )
    }

    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(getSecurityStatusUseCase: getSecurityStatusUseCase)
    }

    func makeSecurityCenterViewModel() -> SecurityCenterViewModel {
        SecurityCenterViewModel(
            getSecurityStatusUseCase: getSecurityStatusUseCase,
            updateAutoLockPolicyUseCase: updateAutoLockPolicyUseCase,
            lockVaultUseCase: lockVaultUseCase
        )
    }

    func makeRecoverySettingsViewModel() -> RecoverySettingsViewModel {
        RecoverySettingsViewModel(
            getRecoveryStatusUseCase: getRecoveryStatusUseCase,
            exportRecoveryPackageUseCase: exportRecoveryPackageUseCase
        )
    }

    func makeRootViewModel() -> RootViewModel {
        RootViewModel(resolveAppRouteUseCase: resolveAppRouteUseCase)
    }
}
