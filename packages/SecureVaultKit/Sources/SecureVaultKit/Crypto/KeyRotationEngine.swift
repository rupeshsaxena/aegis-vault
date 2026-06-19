import Foundation

public protocol KeyRotationEngine: Sendable {
    func createRotationPlan(for keyId: KeyIdentifier) async throws -> KeyRotationPlan
    func rotateVaultEncryptionKey() async throws -> KeyRotationResult
    func rotateItemKey(for objectId: VaultObjectID) async throws -> KeyRotationResult
    func rotateBlobKey(for blobId: BlobID) async throws -> KeyRotationResult
}

public actor FakeKeyRotationEngine: KeyRotationEngine {
    private let keyRegistry: any KeyRegistry
    private let policy: KeyRotationPolicy
    private var objectIdsByKeyId: [KeyIdentifier: [VaultObjectID]]
    private var blobIdsByKeyId: [KeyIdentifier: [BlobID]]

    public init(
        keyRegistry: any KeyRegistry,
        policy: KeyRotationPolicy = KeyRotationPolicy(),
        objectIdsByKeyId: [KeyIdentifier: [VaultObjectID]] = [:],
        blobIdsByKeyId: [KeyIdentifier: [BlobID]] = [:]
    ) {
        self.keyRegistry = keyRegistry
        self.policy = policy
        self.objectIdsByKeyId = objectIdsByKeyId
        self.blobIdsByKeyId = blobIdsByKeyId
    }

    public func createRotationPlan(for keyId: KeyIdentifier) async throws -> KeyRotationPlan {
        let oldKey = try await registeredKey(for: keyId)
        return KeyRotationPlan(
            oldKeyId: keyId,
            newKeyId: KeyIdentifier("\(keyId.rawValue)-v\(oldKey.versionNumber + 1)"),
            affectedObjectIds: objectIdsByKeyId[keyId] ?? [],
            affectedBlobIds: blobIdsByKeyId[keyId] ?? []
        )
    }

    public func rotateVaultEncryptionKey() async throws -> KeyRotationResult {
        try ensureManualRotationAllowed()
        let activeKey = try await keyRegistry.getActiveKey()
        return KeyRotationResult(plan: try await createRotationPlan(for: activeKey.keyId))
    }

    public func rotateItemKey(for objectId: VaultObjectID) async throws -> KeyRotationResult {
        try ensureManualRotationAllowed()
        let keyId = try keyId(containing: objectId)
        var plan = try await createRotationPlan(for: keyId)
        plan.affectedObjectIds = [objectId]
        plan.affectedBlobIds = []
        return KeyRotationResult(plan: plan)
    }

    public func rotateBlobKey(for blobId: BlobID) async throws -> KeyRotationResult {
        try ensureManualRotationAllowed()
        let keyId = try keyId(containing: blobId)
        var plan = try await createRotationPlan(for: keyId)
        plan.affectedObjectIds = []
        plan.affectedBlobIds = [blobId]
        return KeyRotationResult(plan: plan)
    }

    private func registeredKey(for keyId: KeyIdentifier) async throws -> KeyVersion {
        guard let key = await keyRegistry.listKeys().first(where: { $0.keyId == keyId }) else {
            throw VaultError.invalidInput("Unknown key identifier.")
        }
        return key
    }

    private func keyId(containing objectId: VaultObjectID) throws -> KeyIdentifier {
        guard let keyId = objectIdsByKeyId.first(where: { $0.value.contains(objectId) })?.key else {
            throw VaultError.objectNotFound(objectId)
        }
        return keyId
    }

    private func keyId(containing blobId: BlobID) throws -> KeyIdentifier {
        guard let keyId = blobIdsByKeyId.first(where: { $0.value.contains(blobId) })?.key else {
            throw VaultError.invalidInput("Unknown blob identifier.")
        }
        return keyId
    }

    private func ensureManualRotationAllowed() throws {
        guard policy.allowManualRotation else {
            throw VaultError.unsupportedOperation("Manual key rotation is disabled by policy.")
        }
    }
}
