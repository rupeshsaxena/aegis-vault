import Foundation

public final class DefaultVaultEngine: VaultEngine, @unchecked Sendable {
    internal static let defaultTrashRetentionDays = 30

    internal let configuration: VaultKitConfiguration
    internal let sessionActor: VaultSessionActor
    internal let documentImportService: any DocumentImportService
    internal let objectRepository: any VaultObjectRepository
    internal let eventRepository: any VaultEventRepository
    internal let blobRepository: any BlobRepository
    internal let deviceRepository: any DeviceRepository
    internal let transactionCoordinator: any TransactionCoordinator
    internal let thumbnailCache: any ThumbnailCache
    internal let recoveryExportStore: RecoveryExportStore

    internal init(
        configuration: VaultKitConfiguration,
        sessionActor: VaultSessionActor? = nil,
        documentImportService: any DocumentImportService = DefaultDocumentImportService(),
        objectRepository: (any VaultObjectRepository)? = nil,
        eventRepository: (any VaultEventRepository)? = nil,
        transactionCoordinator: (any TransactionCoordinator)? = nil,
        thumbnailCache: (any ThumbnailCache)? = nil,
        recoveryExportStore: RecoveryExportStore? = nil
    ) {
        self.configuration = configuration
        let resolvedThumbnailCache = thumbnailCache ?? InMemoryThumbnailCache()
        self.thumbnailCache = resolvedThumbnailCache
        self.recoveryExportStore = recoveryExportStore ?? RecoveryExportStore()
        self.sessionActor = sessionActor ?? VaultSessionActor(
            cleanupHandler: VaultEngineSessionCleanupHandler(
                searchEngine: configuration.searchEngine,
                thumbnailCache: resolvedThumbnailCache
            )
        )
        self.documentImportService = documentImportService
        let resolvedObjectRepository = objectRepository
            ?? DefaultVaultObjectRepository(storageEngine: configuration.storageEngine)
        self.objectRepository = resolvedObjectRepository
        self.blobRepository = DefaultBlobRepository(blobStore: configuration.blobStore)
        self.deviceRepository = DefaultDeviceRepository(deviceTrustEngine: configuration.deviceTrustEngine)

        if let eventRepository {
            self.eventRepository = eventRepository
        } else if let sqliteStorage = configuration.storageEngine as? SQLiteStorageEngine {
            self.eventRepository = SQLiteVaultEventRepository(storageEngine: sqliteStorage)
        } else {
            self.eventRepository = DefaultVaultEventRepository(eventEngine: configuration.eventEngine)
        }

        if let transactionCoordinator {
            self.transactionCoordinator = transactionCoordinator
        } else if let sqliteStorage = configuration.storageEngine as? SQLiteStorageEngine {
            self.transactionCoordinator = SQLiteTransactionCoordinator(storageEngine: sqliteStorage)
        } else {
            self.transactionCoordinator = InMemoryTransactionCoordinator(
                objectRepository: resolvedObjectRepository,
                eventRepository: self.eventRepository
            )
        }
    }

    public func runtimeStatus() async throws -> VaultRuntimeStatus {
        guard try await configuration.storageEngine.vaultExists() else {
            return .missing
        }
        let header = try await configuration.storageEngine.loadVaultHeader()
        switch await sessionActor.currentState() {
        case .unlocked:
            return .unlocked(header.vaultId)
        case .locked, .unlocking, .locking:
            return .locked(header.vaultId)
        }
    }

    public func securityStatus() async throws -> VaultSecurityStatus {
        guard try await configuration.storageEngine.vaultExists() else {
            throw VaultError.vaultNotFound(VaultID("primary"))
        }
        let header = try await configuration.storageEngine.loadVaultHeader()
        async let devices = trustedDeviceSummaries(for: header)
        async let recovery = recoverySetupStatus()
        let biometricStatus: SecuritySetupStatus
        if let provider = configuration.biometricAuthProvider {
            biometricStatus = await provider.canEvaluatePolicy() ? .configured : .unavailable
        } else {
            biometricStatus = .unavailable
        }
        return try await VaultSecurityStatus(
            vaultId: header.vaultId,
            lockState: sessionActor.currentState(),
            autoLockPolicy: sessionActor.currentAutoLockPolicy(),
            biometricStatus: biometricStatus,
            passkeyStatus: .notConfigured,
            recoveryStatus: recovery,
            trustedDevices: devices
        )
    }

    public func updateAutoLockPolicy(_ policy: AutoLockPolicy) async throws {
        guard try await configuration.storageEngine.vaultExists() else {
            throw VaultError.vaultNotFound(VaultID("primary"))
        }
        await sessionActor.configureAutoLockPolicy(policy)
    }

    public func trustedDeviceSummaries() async throws -> [TrustedDeviceSummary] {
        guard try await configuration.storageEngine.vaultExists() else {
            throw VaultError.vaultNotFound(VaultID("primary"))
        }
        let header = try await configuration.storageEngine.loadVaultHeader()
        return try await trustedDeviceSummaries(for: header)
    }

    public func recoverySetupStatus() async throws -> RecoverySetupStatus {
        guard try await configuration.storageEngine.vaultExists() else {
            throw VaultError.vaultNotFound(VaultID("primary"))
        }
        return .incomplete
    }

    public func getRecoveryStatus() async throws -> RecoveryStatus {
        _ = try await sessionActor.requireUnlocked()
        return await recoveryExportStore.status()
    }

    public func exportRecoveryPackage(
        acknowledgingRisk: Bool
    ) async throws -> RecoveryPackageExport {
        let session = try await sessionActor.requireUnlocked()
        guard acknowledgingRisk else {
            throw VaultError.invalidInput("Recovery export requires explicit acknowledgment.")
        }
        do {
            let export = try await recoveryExportStore.createExport(
                vaultId: session.vaultId,
                deviceId: session.deviceId
            )
            do {
                try await eventRepository.append(
                    .recoveryPackageExported(
                        vaultId: session.vaultId,
                        occurredAt: export.exportedAt
                    )
                )
                return export
            } catch {
                try? await recoveryExportStore.discardFailedExport()
                throw error
            }
        } catch {
            throw VaultError.unsupportedOperation("Unable to export recovery package.")
        }
    }

    public func validateRecoveryPackage(
        from url: URL,
        recoverySecret: RecoverySecret
    ) async throws -> RecoveryValidationResult {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw VaultError.invalidInput("Unable to read recovery package file.")
        }
        let service = DefaultRecoveryPackageService()
        let package = try await service.importRecoveryPackage(from: data)
        return await service.validateRecoveryPackage(package, recoverySecret: recoverySecret)
    }

    public func importRecoveryPackage(
        from url: URL,
        recoverySecret: RecoverySecret
    ) async throws -> RecoveryImportResult {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw VaultError.invalidInput("Unable to read recovery package file.")
        }
        let service = DefaultRecoveryPackageService()
        let package = try await service.importRecoveryPackage(from: data)
        let validation = await service.validateRecoveryPackage(package, recoverySecret: recoverySecret)
        guard validation.isValid else {
            let message = validation.failures.map { failure -> String in
                switch failure {
                case .emptyRecoverySecret: return "Recovery secret must not be empty."
                case .invalidValidationProof: return "Recovery secret is incorrect."
                case .unsupportedFormatVersion: return "Recovery package format is not supported."
                }
            }.joined(separator: " ")
            throw VaultError.invalidInput(message)
        }
        return RecoveryImportResult(
            vaultId: package.vaultId,
            deviceId: package.deviceId,
            recoveredAt: Date(),
            status: .validated
        )
    }

    public func createVault(config: VaultCreationConfig) async throws -> VaultID {
        guard try await !configuration.storageEngine.vaultExists() else {
            throw VaultError.vaultAlreadyExists
        }

        let vaultId = VaultID()
        let rootVaultKey = try await configuration.cryptoEngine.generateRootVaultKey(for: vaultId)
        let vaultEncryptionKey = try await configuration.cryptoEngine.generateVaultEncryptionKey(for: vaultId)
        let wrappedRootKey = try await configuration.cryptoEngine.wrapKey(
            rootVaultKey,
            for: config.deviceID
        )
        let wrappedVaultEncryptionKey = try await configuration.cryptoEngine.wrapKey(
            vaultEncryptionKey,
            for: config.deviceID
        )
        let header = VaultHeaderRecord(
            vaultId: vaultId,
            name: config.name,
            primaryDeviceId: config.deviceID,
            rootKey: wrappedRootKey,
            vaultEncryptionKey: wrappedVaultEncryptionKey
        )

        try await configuration.storageEngine.createVaultHeader(header)
        let deviceIdentity = try await configuration.deviceTrustEngine.createFirstDeviceIdentity(
            deviceId: config.deviceID,
            deviceName: config.name,
            platform: "local",
            vaultId: vaultId
        )
        try await eventRepository.append(.vaultCreated(vaultId: vaultId))
        try await eventRepository.append(.deviceRegistered(vaultId: vaultId, deviceId: deviceIdentity.deviceId))
        try await eventRepository.append(.deviceTrusted(vaultId: vaultId, deviceId: deviceIdentity.deviceId))
        await sessionActor.unlock(
            session: VaultSession(
                vaultId: vaultId,
                deviceId: config.deviceID,
                keyReferences: VaultSessionKeyReferences(
                    rootVaultKeyReference: rootVaultKey.reference,
                    vaultEncryptionKeyReference: vaultEncryptionKey.reference,
                    vaultKeyReference: vaultEncryptionKey.reference
                )
            )
        )

        return vaultId
    }

    public func unlockVault(id: VaultID, using method: UnlockMethod) async throws {
        guard try await configuration.storageEngine.vaultExists() else {
            throw VaultError.vaultNotFound(id)
        }
        try await authorizeUnlock(method)

        let header = try await configuration.storageEngine.loadVaultHeader(vaultId: id)
        let keyMaterial = try await configuration.cryptoEngine.deriveVaultKey(for: id, using: method)
        let records = try await objectRepository.list(
            in: id,
            matching: VaultObjectFilter(includeDeleted: true)
        )

        await sessionActor.unlock(
            session: VaultSession(
                vaultId: id,
                deviceId: header.primaryDeviceId,
                keyReferences: VaultSessionKeyReferences(
                    rootVaultKeyReference: header.rootKey.keyReference,
                    vaultEncryptionKeyReference: header.vaultEncryptionKey.keyReference,
                    vaultKeyReference: keyMaterial.reference
                )
            )
        )
        do {
            let summaries = try await summaries(
                for: records,
                vaultEncryptionKeyReference: header.vaultEncryptionKey.keyReference
            )
            try await configuration.searchEngine.rebuild(from: summaries)
            try await eventRepository.append(VaultEvent(vaultId: id, type: .vaultUnlocked))
        } catch {
            await sessionActor.lock()
            throw error
        }
    }

    public func unlockVault(method: UnlockMethod) async throws {
        guard try await configuration.storageEngine.vaultExists() else {
            throw VaultError.vaultNotFound(VaultID("primary"))
        }
        let header = try await configuration.storageEngine.loadVaultHeader()
        try await unlockVault(id: header.vaultId, using: method)
    }

    public func lockVault(id: VaultID) async {
        await lockVault()
        try? await eventRepository.append(VaultEvent(vaultId: id, type: .vaultLocked))
    }

    public func lockVault() async {
        try? await recoveryExportStore.clearTemporaryExport()
        await thumbnailCache.clear()
        await sessionActor.lock()
    }

    public func loadThumbnail(for objectId: VaultObjectID) async throws -> VaultThumbnail {
        let session = try await sessionActor.requireUnlocked()
        if let cached = await thumbnailCache.value(for: objectId) {
            return cached
        }

        let detail = try await getObjectDetail(id: objectId)
        guard detail.type == .document || detail.type == .photo,
              let attachment = detail.payload.attachments.first(where: { $0.role == .thumbnail }) else {
            throw VaultError.thumbnailNotFound(objectId)
        }
        guard let record = try await configuration.blobStore.listBlobs().first(where: { $0.id == attachment.blobId }),
              let envelope = record.encryptedEnvelope,
              let wrappedKey = record.wrappedKey else {
            throw VaultError.thumbnailNotFound(objectId)
        }

        let wrappingKeyReference = session.keyReferences.vaultEncryptionKeyReference
            ?? session.keyReferences.vaultKeyReference
            ?? "fake-missing-vault-encryption-key"
        let blobKey = try await configuration.cryptoEngine.unwrapKey(
            wrappedKey,
            using: SymmetricKeyMaterial(reference: wrappingKeyReference)
        )
        guard envelope.keyId == blobKey.keyId else {
            throw CryptoError.invalidKeyMaterial
        }

        let workspace = FileManager.default.temporaryDirectory
            .appendingPathComponent("SecureVaultKitThumbnail-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workspace) }
        let encryptedURL = workspace.appendingPathComponent("thumbnail.encrypted")
        let outputURL = workspace.appendingPathComponent("thumbnail.display")
        let encryptedData = try await configuration.blobStore.readBlob(id: attachment.blobId)
        try encryptedData.write(to: encryptedURL, options: .atomic)
        _ = try await configuration.blobEncryptionEngine.decryptBlob(
            inputURL: encryptedURL,
            outputURL: outputURL,
            using: blobKey
        )
        let thumbnail = VaultThumbnail(
            objectId: objectId,
            data: try Data(contentsOf: outputURL),
            contentType: attachment.contentType,
            createdAt: record.createdAt
        )
        await thumbnailCache.insert(thumbnail)
        return thumbnail
    }

    public func createObject(_ draft: VaultObjectDraft) async throws -> VaultObjectID {
        let session = try await sessionActor.requireUnlocked()
        try validateDraft(draft)

        let objectId = VaultObjectID()
        let itemKey = try await configuration.cryptoEngine.generateItemKey(for: objectId)
        let encryptedMetadata = try await configuration.cryptoEngine.encryptMetadata(draft.metadata, using: itemKey)
        let encryptedPayload = try await configuration.cryptoEngine.encryptPayload(draft.payload, using: itemKey)
        let wrappingKeyReference = session.keyReferences.vaultEncryptionKeyReference
            ?? session.keyReferences.vaultKeyReference
            ?? "fake-missing-vault-encryption-key"
        let wrappedItemKey = try await configuration.cryptoEngine.wrapItemKey(
            itemKey,
            usingVaultEncryptionKey: wrappingKeyReference
        )
        let record = VaultObjectRecord(
            id: objectId,
            vaultId: session.vaultId,
            type: draft.type,
            encryptedMetadata: encryptedMetadata,
            encryptedPayload: encryptedPayload,
            wrappedItemKey: wrappedItemKey,
            isDeleted: draft.metadata.deletedAt != nil,
            deletedAt: draft.metadata.deletedAt,
            version: 1,
            createdAt: draft.metadata.createdAt,
            updatedAt: draft.metadata.updatedAt
        )
        let summary = VaultObjectSummary(
            id: objectId,
            vaultId: session.vaultId,
            type: draft.type,
            title: draft.metadata.title,
            subtitle: draft.metadata.subtitle,
            tags: draft.metadata.tags,
            updatedAt: draft.metadata.updatedAt,
            isDeleted: draft.metadata.deletedAt != nil,
            deletedAt: draft.metadata.deletedAt,
            version: 1
        )

        try await transactionCoordinator.execute(
            .insert(record),
            appending: .objectCreated(vaultId: session.vaultId, objectId: objectId)
        )
        try await configuration.searchEngine.index(summary)

        return objectId
    }

    public func createObject(_ draft: VaultObjectDraft, in vaultID: VaultID) async throws -> VaultObjectDetail {
        let objectId = try await createObject(draft)
        return VaultObjectDetail(
            id: objectId,
            type: draft.type,
            metadata: draft.metadata,
            payload: draft.payload,
            version: 1
        )
    }

    public func listObjects(filter: VaultObjectFilter = VaultObjectFilter()) async throws -> [VaultObjectSummary] {
        let session = try await sessionActor.requireUnlocked()
        let records = try await objectRepository.list(
            in: session.vaultId,
            includeDeleted: filter.includeDeleted
        )

        var summaries: [VaultObjectSummary] = []
        for record in records where filter.types.isEmpty || filter.types.contains(record.type) {
            let itemKey = try await configuration.cryptoEngine.unwrapItemKey(
                record.wrappedItemKey,
                usingVaultEncryptionKey: session.keyReferences.vaultEncryptionKeyReference ?? ""
            )
            let metadata = try await configuration.cryptoEngine.decryptMetadata(record.encryptedMetadata, using: itemKey)
            guard filter.includeDeleted || metadata.deletedAt == nil else { continue }
            guard filter.tags.allSatisfy(metadata.tags.contains) else { continue }
            let summary = VaultObjectSummary(
                id: record.id,
                vaultId: record.vaultId,
                type: record.type,
                title: metadata.title,
                subtitle: metadata.subtitle,
                tags: metadata.tags,
                updatedAt: metadata.updatedAt,
                isDeleted: metadata.deletedAt != nil,
                deletedAt: metadata.deletedAt,
                version: record.version
            )
            guard matchesQuery(summary, query: filter.query) else { continue }
            summaries.append(summary)
        }

        return summaries.sorted { $0.updatedAt < $1.updatedAt }
    }

    public func searchObjects(query: String) async throws -> [VaultObjectSummary] {
        try await searchObjects(query: query, filter: VaultObjectFilter())
    }

    public func searchObjects(
        query: String,
        filter: VaultObjectFilter
    ) async throws -> [VaultObjectSummary] {
        _ = try await sessionActor.requireUnlocked()
        return try await configuration.searchEngine.search(query: query, filter: filter).map(\.summary)
    }

    public func getObjectDetail(id: VaultObjectID) async throws -> VaultObjectDetail {
        let session = try await sessionActor.requireUnlocked()
        let record = try await objectRepository.load(id: id)
        guard record.vaultId == session.vaultId else {
            throw VaultError.objectNotFound(id)
        }
        let itemKey = try await configuration.cryptoEngine.unwrapItemKey(
            record.wrappedItemKey,
            usingVaultEncryptionKey: session.keyReferences.vaultEncryptionKeyReference ?? ""
        )
        let metadata = try await configuration.cryptoEngine.decryptMetadata(record.encryptedMetadata, using: itemKey)
        let payload = try await configuration.cryptoEngine.decryptPayload(record.encryptedPayload, using: itemKey)

        return VaultObjectDetail(
            id: record.id,
            type: record.type,
            metadata: metadata,
            payload: payload,
            version: record.version
        )
    }

    public func updateObject(_ update: VaultObjectUpdate) async throws -> VaultObjectDetail {
        guard let objectId = update.objectId else {
            throw VaultError.invalidInput("Object update requires objectId.")
        }
        return try await updateObject(id: objectId, with: update)
    }

    public func updateObject(id: VaultObjectID, with update: VaultObjectUpdate) async throws -> VaultObjectDetail {
        let session = try await sessionActor.requireUnlocked()
        let existingRecord = try await objectRepository.load(id: id)
        guard existingRecord.vaultId == session.vaultId else {
            throw VaultError.objectNotFound(id)
        }
        guard !existingRecord.isDeleted else {
            throw VaultError.invalidInput("Cannot update a deleted object.")
        }
        guard update.metadata != nil || update.payload != nil else {
            throw VaultError.invalidInput("Object update must include metadata or payload.")
        }

        let currentKey = try await configuration.cryptoEngine.unwrapItemKey(
            existingRecord.wrappedItemKey,
            usingVaultEncryptionKey: session.keyReferences.vaultEncryptionKeyReference ?? ""
        )
        let currentMetadata = try await configuration.cryptoEngine.decryptMetadata(
            existingRecord.encryptedMetadata,
            using: currentKey
        )
        let currentPayload = try await configuration.cryptoEngine.decryptPayload(
            existingRecord.encryptedPayload,
            using: currentKey
        )
        let updatedMetadata = update.metadata ?? currentMetadata
        let updatedPayload = update.payload ?? currentPayload
        try validateUpdate(metadata: updatedMetadata)

        let updatedVersion = existingRecord.version + 1
        let itemKey = try await configuration.cryptoEngine.generateItemKey(for: id)
        let encryptedMetadata = try await configuration.cryptoEngine.encryptMetadata(updatedMetadata, using: itemKey)
        let encryptedPayload = try await configuration.cryptoEngine.encryptPayload(updatedPayload, using: itemKey)
        let wrappedItemKey = try await configuration.cryptoEngine.wrapItemKey(
            itemKey,
            usingVaultEncryptionKey: session.keyReferences.vaultEncryptionKeyReference
                ?? session.keyReferences.vaultKeyReference
                ?? "fake-missing-vault-encryption-key"
        )
        let updatedRecord = VaultObjectRecord(
            id: existingRecord.id,
            vaultId: existingRecord.vaultId,
            type: existingRecord.type,
            encryptedMetadata: encryptedMetadata,
            encryptedPayload: encryptedPayload,
            wrappedItemKey: wrappedItemKey,
            isDeleted: false,
            deletedAt: nil,
            version: updatedVersion,
            createdAt: existingRecord.createdAt,
            updatedAt: updatedMetadata.updatedAt
        )

        try await transactionCoordinator.execute(
            .update(previous: existingRecord, updated: updatedRecord),
            appending: .objectUpdated(
                vaultId: session.vaultId,
                objectId: id,
                objectVersion: updatedVersion
            )
        )
        try await configuration.searchEngine.index(summary(for: updatedRecord, metadata: updatedMetadata))

        return VaultObjectDetail(
            id: id,
            type: existingRecord.type,
            metadata: updatedMetadata,
            payload: updatedPayload,
            version: updatedVersion
        )
    }

    public func objectDetail(id: VaultObjectID) async throws -> VaultObjectDetail {
        try await getObjectDetail(id: id)
    }

    public func objectSummaries(in vaultID: VaultID, matching filter: VaultObjectFilter) async throws -> [VaultObjectSummary] {
        try await listObjects(filter: filter)
    }

    public func importDocument(_ input: DocumentImportInput, into vaultID: VaultID) async throws -> DocumentImportResult {
        let session = try await sessionActor.requireUnlocked()
        guard session.vaultId == vaultID else {
            throw VaultError.vaultNotFound(vaultID)
        }
        return try await documentImportService.importDocument(
            input,
            into: vaultID,
            session: session,
            configuration: configuration
        )
    }

    public func moveToTrash(_ id: VaultObjectID) async throws {
        let session = try await sessionActor.requireUnlocked()
        let record = try await objectRepository.load(id: id)
        guard record.vaultId == session.vaultId else {
            throw VaultError.objectNotFound(id)
        }
        let deletedAt = Date()
        let itemKey = try await configuration.cryptoEngine.unwrapItemKey(
            record.wrappedItemKey,
            usingVaultEncryptionKey: session.keyReferences.vaultEncryptionKeyReference ?? ""
        )
        var metadata = try await configuration.cryptoEngine.decryptMetadata(record.encryptedMetadata, using: itemKey)
        metadata.deletedAt = deletedAt
        let encryptedMetadata = try await configuration.cryptoEngine.encryptMetadata(metadata, using: itemKey)
        var deletedRecord = record
        deletedRecord.isDeleted = true
        deletedRecord.deletedAt = deletedAt
        deletedRecord.encryptedMetadata = encryptedMetadata
        deletedRecord.updatedAt = deletedAt
        try await transactionCoordinator.execute(
            .update(previous: record, updated: deletedRecord),
            appending: .objectDeleted(vaultId: session.vaultId, objectId: id)
        )
        try await configuration.searchEngine.remove(objectId: id)
    }

    public func restoreFromTrash(_ id: VaultObjectID) async throws {
        let session = try await sessionActor.requireUnlocked()
        let record = try await objectRepository.load(id: id)
        guard record.vaultId == session.vaultId else {
            throw VaultError.objectNotFound(id)
        }
        let restoredAt = Date()
        let itemKey = try await configuration.cryptoEngine.unwrapItemKey(
            record.wrappedItemKey,
            usingVaultEncryptionKey: session.keyReferences.vaultEncryptionKeyReference ?? ""
        )
        var metadata = try await configuration.cryptoEngine.decryptMetadata(record.encryptedMetadata, using: itemKey)
        metadata.deletedAt = nil
        metadata.updatedAt = restoredAt
        let encryptedMetadata = try await configuration.cryptoEngine.encryptMetadata(metadata, using: itemKey)
        var restoredRecord = record
        restoredRecord.isDeleted = false
        restoredRecord.deletedAt = nil
        restoredRecord.encryptedMetadata = encryptedMetadata
        restoredRecord.updatedAt = restoredAt
        try await transactionCoordinator.execute(
            .update(previous: record, updated: restoredRecord),
            appending: .objectRestored(vaultId: session.vaultId, objectId: id)
        )
        try await configuration.searchEngine.index(summary(for: restoredRecord, metadata: metadata))
    }

    public func purgeTrash() async throws {
        let session = try await sessionActor.requireUnlocked()
        let cutoff = Date().addingTimeInterval(-Double(Self.defaultTrashRetentionDays) * 24 * 60 * 60)
        let purgedRecords = try await objectRepository.purgeDeleted(
            in: session.vaultId,
            olderThan: cutoff
        )
        for record in purgedRecords {
            try await eventRepository.append(.objectPurged(vaultId: session.vaultId, objectId: record.id))
            try await configuration.searchEngine.remove(objectId: record.id)
        }
    }

    public func permanentlyDeleteObject(_ id: VaultObjectID) async throws {
        let session = try await sessionActor.requireUnlocked()
        let record = try await objectRepository.load(id: id)
        guard record.vaultId == session.vaultId else {
            throw VaultError.objectNotFound(id)
        }
        guard record.isDeleted else {
            throw VaultError.invalidInput("Only objects in Trash can be permanently deleted.")
        }

        try await transactionCoordinator.execute(
            .delete(record),
            appending: .objectPurged(vaultId: session.vaultId, objectId: id)
        )
        try await configuration.searchEngine.remove(objectId: id)
        await thumbnailCache.removeValue(for: id)
    }

    public func moveObjectToTrash(id: VaultObjectID) async throws {
        try await moveToTrash(id)
    }

    private func authorizeUnlock(_ method: UnlockMethod) async throws {
        switch method {
        case .biometric:
            guard let provider = configuration.biometricAuthProvider,
                  await provider.canEvaluatePolicy() else {
                throw VaultError.biometricUnavailable
            }
            do {
                switch try await provider.authenticate(reason: "Unlock AegisVault") {
                case .success:
                    return
                case .cancelled:
                    throw VaultError.authenticationCancelled
                case .failed:
                    throw VaultError.authenticationFailed
                case .unavailable:
                    throw VaultError.biometricUnavailable
                }
            } catch let error as BiometricAuthError {
                switch error {
                case .unavailable:
                    throw VaultError.biometricUnavailable
                case .cancelled:
                    throw VaultError.authenticationCancelled
                case .failed:
                    throw VaultError.authenticationFailed
                case .lockedOut:
                    throw VaultError.biometricLockedOut
                case .notEnrolled:
                    throw VaultError.biometricNotEnrolled
                }
            }
        case .recoverySecret(let secret) where secret.isEmpty:
            throw VaultError.invalidInput("Recovery secret must not be empty.")
        default:
            break
        }
    }

    private func trustedDeviceSummaries(
        for header: VaultHeaderRecord
    ) async throws -> [TrustedDeviceSummary] {
        try await deviceRepository.list(for: header.vaultId).map { device in
            TrustedDeviceSummary(
                deviceId: device.deviceId,
                name: device.deviceName,
                platform: device.platform,
                createdAt: device.createdAt,
                isCurrentDevice: device.deviceId == header.primaryDeviceId
            )
        }
    }

    private func validateDraft(_ draft: VaultObjectDraft) throws {
        guard !draft.metadata.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw VaultError.invalidInput("Object title must not be empty.")
        }

        guard VaultObjectType.allCases.contains(draft.type) else {
            throw VaultError.invalidInput("Unsupported object type.")
        }

        let hasPayload = !(draft.payload.notes ?? "").isEmpty
            || !draft.payload.fields.isEmpty
            || !draft.payload.attachments.isEmpty
        if !hasPayload && draft.type != .document && draft.type != .photo {
            throw VaultError.invalidInput("Object payload must not be empty.")
        }
    }

    private func matchesQuery(_ summary: VaultObjectSummary, query: String?) -> Bool {
        guard let query, !query.isEmpty else {
            return true
        }
        return summary.title.localizedCaseInsensitiveContains(query)
            || (summary.subtitle?.localizedCaseInsensitiveContains(query) ?? false)
    }

    private func summary(for record: VaultObjectRecord, metadata: VaultMetadata) -> VaultObjectSummary {
        VaultObjectSummary(
            id: record.id,
            vaultId: record.vaultId,
            type: record.type,
            title: metadata.title,
            subtitle: metadata.subtitle,
            tags: metadata.tags,
            updatedAt: metadata.updatedAt,
            isDeleted: metadata.deletedAt != nil,
            deletedAt: metadata.deletedAt,
            version: record.version
        )
    }

    private func summaries(for records: [VaultObjectRecord], vaultEncryptionKeyReference: String) async throws -> [VaultObjectSummary] {
        var summaries: [VaultObjectSummary] = []
        for record in records {
            let itemKey = try await configuration.cryptoEngine.unwrapItemKey(
                record.wrappedItemKey,
                usingVaultEncryptionKey: vaultEncryptionKeyReference
            )
            let metadata = try await configuration.cryptoEngine.decryptMetadata(record.encryptedMetadata, using: itemKey)
            summaries.append(summary(for: record, metadata: metadata))
        }
        return summaries
    }

    private func validateUpdate(metadata: VaultMetadata) throws {
        guard !metadata.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw VaultError.invalidInput("Object title must not be empty.")
        }
    }
}
