import Foundation

public final class DefaultVaultEngine: VaultEngine, @unchecked Sendable {
    internal static let defaultTrashRetentionDays = 30

    internal let configuration: VaultKitConfiguration
    internal let sessionActor: VaultSessionActor

    internal init(
        configuration: VaultKitConfiguration,
        sessionActor: VaultSessionActor = VaultSessionActor()
    ) {
        self.configuration = configuration
        self.sessionActor = sessionActor
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
        let deviceIdentity = DeviceIdentity(
            id: config.deviceID,
            displayName: config.name,
            publicKeyReference: "fake-device-public-key-\(config.deviceID.rawValue)"
        )
        let header = VaultHeaderRecord(
            vaultId: vaultId,
            name: config.name,
            primaryDeviceId: config.deviceID,
            rootKey: wrappedRootKey,
            vaultEncryptionKey: wrappedVaultEncryptionKey
        )

        try await configuration.storageEngine.createVaultHeader(header)
        try await configuration.deviceTrustEngine.trustDevice(deviceIdentity, for: vaultId)
        try await configuration.eventEngine.append(.vaultCreated(vaultId: vaultId))
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
        try validateFakeUnlockMethod(method)

        let header = try await configuration.storageEngine.loadVaultHeader(vaultId: id)
        let keyMaterial = try await configuration.cryptoEngine.deriveVaultKey(for: id, using: method)
        let records = try await configuration.storageEngine.queryObjects(
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
        try await configuration.searchEngine.rebuild(for: records)
        try await configuration.eventEngine.append(VaultEvent(vaultId: id, type: .vaultUnlocked))
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
        try? await configuration.eventEngine.append(VaultEvent(vaultId: id, type: .vaultLocked))
    }

    public func lockVault() async {
        await configuration.searchEngine.clear()
        await sessionActor.lock()
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
            isDeleted: draft.metadata.deletedAt != nil
        )

        try await configuration.storageEngine.insertObject(record)
        try await configuration.eventEngine.append(.objectCreated(vaultId: session.vaultId, objectId: objectId))
        try await configuration.searchEngine.indexSummary(summary)

        return objectId
    }

    public func createObject(_ draft: VaultObjectDraft, in vaultID: VaultID) async throws -> VaultObjectDetail {
        let objectId = try await createObject(draft)
        return VaultObjectDetail(
            id: objectId,
            type: draft.type,
            metadata: draft.metadata,
            payload: draft.payload
        )
    }

    public func listObjects(filter: VaultObjectFilter = VaultObjectFilter()) async throws -> [VaultObjectSummary] {
        let session = try await sessionActor.requireUnlocked()
        let records = try await configuration.storageEngine.listObjects(
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
                isDeleted: metadata.deletedAt != nil
            )
            guard matchesQuery(summary, query: filter.query) else { continue }
            summaries.append(summary)
        }

        return summaries.sorted { $0.updatedAt < $1.updatedAt }
    }

    public func getObjectDetail(id: VaultObjectID) async throws -> VaultObjectDetail {
        let session = try await sessionActor.requireUnlocked()
        let record = try await configuration.storageEngine.loadObject(id: id)
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
            payload: payload
        )
    }

    public func updateObject(id: VaultObjectID, with update: VaultObjectUpdate) async throws -> VaultObjectDetail {
        throw VaultError.unsupportedOperation("Object updates are not implemented yet.")
    }

    public func objectDetail(id: VaultObjectID) async throws -> VaultObjectDetail {
        try await getObjectDetail(id: id)
    }

    public func objectSummaries(in vaultID: VaultID, matching filter: VaultObjectFilter) async throws -> [VaultObjectSummary] {
        try await listObjects(filter: filter)
    }

    public func importDocument(_ input: DocumentImportInput, into vaultID: VaultID) async throws -> VaultAttachment {
        throw VaultError.unsupportedOperation("Document import is not implemented yet.")
    }

    public func moveToTrash(_ id: VaultObjectID) async throws {
        let session = try await sessionActor.requireUnlocked()
        let record = try await configuration.storageEngine.loadObject(id: id)
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
        var deletedRecord = try await configuration.storageEngine.markDeleted(id: id, at: deletedAt)
        deletedRecord.encryptedMetadata = encryptedMetadata
        deletedRecord.updatedAt = deletedAt
        try await configuration.storageEngine.writeObject(deletedRecord)
        try await configuration.eventEngine.append(.objectDeleted(vaultId: session.vaultId, objectId: id))
        try await configuration.searchEngine.removeObject(id: id)
    }

    public func restoreFromTrash(_ id: VaultObjectID) async throws {
        let session = try await sessionActor.requireUnlocked()
        let record = try await configuration.storageEngine.loadObject(id: id)
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
        var restoredRecord = try await configuration.storageEngine.restoreDeleted(id: id)
        restoredRecord.encryptedMetadata = encryptedMetadata
        restoredRecord.updatedAt = restoredAt
        try await configuration.storageEngine.writeObject(restoredRecord)
        try await configuration.eventEngine.append(.objectRestored(vaultId: session.vaultId, objectId: id))
        try await configuration.searchEngine.indexSummary(summary(for: restoredRecord, metadata: metadata))
    }

    public func purgeTrash() async throws {
        let session = try await sessionActor.requireUnlocked()
        let cutoff = Date().addingTimeInterval(-Double(Self.defaultTrashRetentionDays) * 24 * 60 * 60)
        let purgedRecords = try await configuration.storageEngine.purgeDeleted(
            in: session.vaultId,
            olderThan: cutoff
        )
        for record in purgedRecords {
            try await configuration.eventEngine.append(.objectPurged(vaultId: session.vaultId, objectId: record.id))
            try await configuration.searchEngine.removeObject(id: record.id)
        }
    }

    public func moveObjectToTrash(id: VaultObjectID) async throws {
        try await moveToTrash(id)
    }

    private func validateFakeUnlockMethod(_ method: UnlockMethod) throws {
        switch method {
        case .recoverySecret(let secret) where secret.isEmpty:
            throw VaultError.invalidInput("Recovery secret must not be empty.")
        default:
            break
        }
    }

    private func validateDraft(_ draft: VaultObjectDraft) throws {
        guard !draft.metadata.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw VaultError.invalidInput("Object title must not be empty.")
        }

        guard VaultObjectType.allCases.contains(draft.type) else {
            throw VaultError.invalidInput("Unsupported object type.")
        }

        let hasPayload = !draft.payload.fields.isEmpty || !draft.payload.attachments.isEmpty
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
            isDeleted: metadata.deletedAt != nil
        )
    }
}
