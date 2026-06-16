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
        let header = try await configuration.storageEngine.loadVaultHeader(vaultId: id)
        let keyMaterial = try await configuration.cryptoEngine.deriveVaultKey(for: id, using: method)

        await sessionActor.unlock(
            session: VaultSession(
                vaultId: id,
                deviceId: header.primaryDeviceId,
                keyReferences: VaultSessionKeyReferences(vaultKeyReference: keyMaterial.reference)
            )
        )
        try await configuration.eventEngine.append(VaultEvent(vaultId: id, type: .vaultUnlocked))
    }

    public func lockVault(id: VaultID) async {
        await sessionActor.lock()
        try? await configuration.eventEngine.append(VaultEvent(vaultId: id, type: .vaultLocked))
    }

    public func createObject(_ draft: VaultObjectDraft, in vaultID: VaultID) async throws -> VaultObjectDetail {
        throw VaultError.unsupportedOperation("Object creation is not implemented yet.")
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
}
