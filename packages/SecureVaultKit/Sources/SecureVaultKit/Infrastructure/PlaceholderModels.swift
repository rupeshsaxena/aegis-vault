import Foundation

internal struct SymmetricKeyMaterial: Equatable, Sendable {
    var reference: String

    init(reference: String) {
        self.reference = reference
    }
}

internal struct EncryptedEnvelope: Equatable, Sendable {
    var algorithm: String
    var keyReference: String
    var ciphertextReference: String

    init(algorithm: String, keyReference: String, ciphertextReference: String) {
        self.algorithm = algorithm
        self.keyReference = keyReference
        self.ciphertextReference = ciphertextReference
    }
}

internal struct WrappedKey: Equatable, Sendable {
    var keyReference: String
    var wrappedByDeviceId: DeviceID

    init(keyReference: String, wrappedByDeviceId: DeviceID) {
        self.keyReference = keyReference
        self.wrappedByDeviceId = wrappedByDeviceId
    }
}

internal struct VaultHeaderRecord: Equatable, Sendable {
    var vaultId: VaultID
    var primaryDeviceId: DeviceID
    var wrappedKey: WrappedKey
    var createdAt: Date

    init(vaultId: VaultID, primaryDeviceId: DeviceID, wrappedKey: WrappedKey, createdAt: Date = Date()) {
        self.vaultId = vaultId
        self.primaryDeviceId = primaryDeviceId
        self.wrappedKey = wrappedKey
        self.createdAt = createdAt
    }
}

internal struct VaultObjectRecord: Equatable, Sendable {
    var id: VaultObjectID
    var vaultId: VaultID
    var type: VaultObjectType
    var metadata: VaultMetadata
    var encryptedPayload: EncryptedEnvelope

    init(
        id: VaultObjectID,
        vaultId: VaultID,
        type: VaultObjectType,
        metadata: VaultMetadata,
        encryptedPayload: EncryptedEnvelope
    ) {
        self.id = id
        self.vaultId = vaultId
        self.type = type
        self.metadata = metadata
        self.encryptedPayload = encryptedPayload
    }
}

internal struct BlobWriteResult: Equatable, Sendable {
    var id: BlobID
    var byteCount: Int
    var contentType: String

    init(id: BlobID, byteCount: Int, contentType: String) {
        self.id = id
        self.byteCount = byteCount
        self.contentType = contentType
    }
}

internal enum VaultEventType: String, Sendable {
    case vaultCreated
    case vaultUnlocked
    case vaultLocked
    case objectCreated
    case objectUpdated
    case objectDeleted
}

internal struct VaultEvent: Equatable, Sendable {
    var vaultId: VaultID
    var type: VaultEventType
    var objectId: VaultObjectID?
    var occurredAt: Date

    init(
        vaultId: VaultID,
        type: VaultEventType,
        objectId: VaultObjectID? = nil,
        occurredAt: Date = Date()
    ) {
        self.vaultId = vaultId
        self.type = type
        self.objectId = objectId
        self.occurredAt = occurredAt
    }
}

internal struct DeviceIdentity: Equatable, Sendable {
    var id: DeviceID
    var displayName: String
    var publicKeyReference: String

    init(id: DeviceID, displayName: String, publicKeyReference: String) {
        self.id = id
        self.displayName = displayName
        self.publicKeyReference = publicKeyReference
    }
}
