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
    var wrappedByDeviceId: DeviceID?
    var wrappingKeyReference: String?

    init(keyReference: String, wrappedByDeviceId: DeviceID? = nil, wrappingKeyReference: String? = nil) {
        self.keyReference = keyReference
        self.wrappedByDeviceId = wrappedByDeviceId
        self.wrappingKeyReference = wrappingKeyReference
    }
}

internal struct VaultHeaderRecord: Equatable, Sendable {
    var vaultId: VaultID
    var name: String
    var primaryDeviceId: DeviceID
    var rootKey: WrappedKey
    var vaultEncryptionKey: WrappedKey
    var createdAt: Date

    init(
        vaultId: VaultID,
        name: String,
        primaryDeviceId: DeviceID,
        rootKey: WrappedKey,
        vaultEncryptionKey: WrappedKey,
        createdAt: Date = Date()
    ) {
        self.vaultId = vaultId
        self.name = name
        self.primaryDeviceId = primaryDeviceId
        self.rootKey = rootKey
        self.vaultEncryptionKey = vaultEncryptionKey
        self.createdAt = createdAt
    }
}

internal struct VaultObjectRecord: Equatable, Sendable {
    var id: VaultObjectID
    var vaultId: VaultID
    var type: VaultObjectType
    var encryptedMetadata: EncryptedEnvelope
    var encryptedPayload: EncryptedEnvelope
    var wrappedItemKey: WrappedKey
    var isDeleted: Bool
    var deletedAt: Date?
    var version: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: VaultObjectID,
        vaultId: VaultID,
        type: VaultObjectType,
        encryptedMetadata: EncryptedEnvelope,
        encryptedPayload: EncryptedEnvelope,
        wrappedItemKey: WrappedKey,
        isDeleted: Bool = false,
        deletedAt: Date? = nil,
        version: Int = 1,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.vaultId = vaultId
        self.type = type
        self.encryptedMetadata = encryptedMetadata
        self.encryptedPayload = encryptedPayload
        self.wrappedItemKey = wrappedItemKey
        self.isDeleted = isDeleted
        self.deletedAt = deletedAt
        self.version = version
        self.createdAt = createdAt
        self.updatedAt = updatedAt
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
    case vaultCreated = "vault_created"
    case vaultUnlocked
    case vaultLocked
    case objectCreated
    case objectUpdated = "object_updated"
    case objectDeleted = "object_deleted"
    case objectRestored = "object_restored"
    case objectPurged = "object_purged"
}

internal struct VaultEvent: Equatable, Sendable {
    var vaultId: VaultID
    var type: VaultEventType
    var objectId: VaultObjectID?
    var objectVersion: Int?
    var occurredAt: Date

    init(
        vaultId: VaultID,
        type: VaultEventType,
        objectId: VaultObjectID? = nil,
        objectVersion: Int? = nil,
        occurredAt: Date = Date()
    ) {
        self.vaultId = vaultId
        self.type = type
        self.objectId = objectId
        self.objectVersion = objectVersion
        self.occurredAt = occurredAt
    }

    static func vaultCreated(vaultId: VaultID, occurredAt: Date = Date()) -> VaultEvent {
        VaultEvent(vaultId: vaultId, type: .vaultCreated, occurredAt: occurredAt)
    }

    static func objectCreated(vaultId: VaultID, objectId: VaultObjectID, occurredAt: Date = Date()) -> VaultEvent {
        VaultEvent(vaultId: vaultId, type: .objectCreated, objectId: objectId, occurredAt: occurredAt)
    }

    static func objectUpdated(vaultId: VaultID, objectId: VaultObjectID, objectVersion: Int, occurredAt: Date = Date()) -> VaultEvent {
        VaultEvent(
            vaultId: vaultId,
            type: .objectUpdated,
            objectId: objectId,
            objectVersion: objectVersion,
            occurredAt: occurredAt
        )
    }

    static func objectDeleted(vaultId: VaultID, objectId: VaultObjectID, occurredAt: Date = Date()) -> VaultEvent {
        VaultEvent(vaultId: vaultId, type: .objectDeleted, objectId: objectId, occurredAt: occurredAt)
    }

    static func objectRestored(vaultId: VaultID, objectId: VaultObjectID, occurredAt: Date = Date()) -> VaultEvent {
        VaultEvent(vaultId: vaultId, type: .objectRestored, objectId: objectId, occurredAt: occurredAt)
    }

    static func objectPurged(vaultId: VaultID, objectId: VaultObjectID, occurredAt: Date = Date()) -> VaultEvent {
        VaultEvent(vaultId: vaultId, type: .objectPurged, objectId: objectId, occurredAt: occurredAt)
    }
}

internal struct DeviceIdentity: Equatable, Sendable {
    var id: DeviceID
    var displayName: String
    var publicKeyReference: String
    var trustedAt: Date

    init(id: DeviceID, displayName: String, publicKeyReference: String, trustedAt: Date = Date()) {
        self.id = id
        self.displayName = displayName
        self.publicKeyReference = publicKeyReference
        self.trustedAt = trustedAt
    }
}
