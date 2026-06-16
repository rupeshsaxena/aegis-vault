import Foundation

public final class DefaultVaultEngine: VaultEngine, @unchecked Sendable {
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

    public func updateObject(id: VaultObjectID, with update: VaultObjectUpdate) async throws -> VaultObjectDetail {
        throw VaultError.unsupportedOperation("Object updates are not implemented yet.")
    }

    public func objectDetail(id: VaultObjectID) async throws -> VaultObjectDetail {
        throw VaultError.unsupportedOperation("Object detail loading is not implemented yet.")
    }

    public func objectSummaries(in vaultID: VaultID, matching filter: VaultObjectFilter) async throws -> [VaultObjectSummary] {
        throw VaultError.unsupportedOperation("Object summaries are not implemented yet.")
    }

    public func importDocument(_ input: DocumentImportInput, into vaultID: VaultID) async throws -> VaultAttachment {
        throw VaultError.unsupportedOperation("Document import is not implemented yet.")
    }

    public func moveObjectToTrash(id: VaultObjectID) async throws {
        throw VaultError.unsupportedOperation("Trash operations are not implemented yet.")
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
}
