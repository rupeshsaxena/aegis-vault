import Foundation

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

internal enum VaultEventType: String, Sendable {
    case vaultCreated = "vault_created"
    case vaultUnlocked
    case vaultLocked
    case deviceRegistered = "device_registered"
    case deviceTrusted = "device_trusted"
    case deviceRevoked = "device_revoked"
    case deviceLost = "device_lost"
    case objectCreated
    case objectUpdated = "object_updated"
    case objectDeleted = "object_deleted"
    case objectRestored = "object_restored"
    case objectPurged = "object_purged"
    case attachmentAdded = "attachment_added"
}

internal struct VaultEvent: Equatable, Sendable {
    var vaultId: VaultID
    var type: VaultEventType
    var objectId: VaultObjectID?
    var blobId: BlobID?
    var deviceId: DeviceID?
    var objectVersion: Int?
    var occurredAt: Date

    init(
        vaultId: VaultID,
        type: VaultEventType,
        objectId: VaultObjectID? = nil,
        blobId: BlobID? = nil,
        deviceId: DeviceID? = nil,
        objectVersion: Int? = nil,
        occurredAt: Date = Date()
    ) {
        self.vaultId = vaultId
        self.type = type
        self.objectId = objectId
        self.blobId = blobId
        self.deviceId = deviceId
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

    static func attachmentAdded(
        vaultId: VaultID,
        objectId: VaultObjectID,
        blobId: BlobID,
        occurredAt: Date = Date()
    ) -> VaultEvent {
        VaultEvent(
            vaultId: vaultId,
            type: .attachmentAdded,
            objectId: objectId,
            blobId: blobId,
            occurredAt: occurredAt
        )
    }

    static func deviceRegistered(vaultId: VaultID, deviceId: DeviceID, occurredAt: Date = Date()) -> VaultEvent {
        VaultEvent(vaultId: vaultId, type: .deviceRegistered, deviceId: deviceId, occurredAt: occurredAt)
    }

    static func deviceTrusted(vaultId: VaultID, deviceId: DeviceID, occurredAt: Date = Date()) -> VaultEvent {
        VaultEvent(vaultId: vaultId, type: .deviceTrusted, deviceId: deviceId, occurredAt: occurredAt)
    }

    static func deviceRevoked(vaultId: VaultID, deviceId: DeviceID, occurredAt: Date = Date()) -> VaultEvent {
        VaultEvent(vaultId: vaultId, type: .deviceRevoked, deviceId: deviceId, occurredAt: occurredAt)
    }

    static func deviceLost(vaultId: VaultID, deviceId: DeviceID, occurredAt: Date = Date()) -> VaultEvent {
        VaultEvent(vaultId: vaultId, type: .deviceLost, deviceId: deviceId, occurredAt: occurredAt)
    }
}

internal enum DeviceTrustState: String, Codable, Sendable {
    case pending
    case trusted
    case revoked
    case lost
}

internal enum DevicePermission: String, CaseIterable, Codable, Sendable {
    case read
    case write
    case sync
    case manageDevices
}

internal struct DeviceIdentity: Equatable, Sendable {
    var deviceId: DeviceID
    var deviceName: String
    var platform: String
    var publicKey: String
    var createdAt: Date
    var trustState: DeviceTrustState
    var permissions: [DevicePermission]

    init(
        deviceId: DeviceID,
        deviceName: String,
        platform: String,
        publicKey: String,
        createdAt: Date = Date(),
        trustState: DeviceTrustState = .pending,
        permissions: [DevicePermission] = []
    ) {
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.platform = platform
        self.publicKey = publicKey
        self.createdAt = createdAt
        self.trustState = trustState
        self.permissions = permissions
    }

    init(id: DeviceID, displayName: String, publicKeyReference: String, trustedAt: Date = Date()) {
        self.init(
            deviceId: id,
            deviceName: displayName,
            platform: "unknown",
            publicKey: publicKeyReference,
            createdAt: trustedAt,
            trustState: .trusted,
            permissions: [.read, .write, .sync]
        )
    }

    var id: DeviceID {
        deviceId
    }

    var displayName: String {
        deviceName
    }

    var publicKeyReference: String {
        publicKey
    }

    var trustedAt: Date {
        createdAt
    }
}

internal struct TrustCertificate: Equatable, Sendable {
    var certificateId: String
    var vaultId: VaultID
    var deviceId: DeviceID
    var issuedByDeviceId: DeviceID
    var issuedAt: Date
    var expiresAt: Date?
    var permissions: [DevicePermission]
    var signature: String

    init(
        certificateId: String = UUID().uuidString,
        vaultId: VaultID,
        deviceId: DeviceID,
        issuedByDeviceId: DeviceID,
        issuedAt: Date = Date(),
        expiresAt: Date? = nil,
        permissions: [DevicePermission],
        signature: String
    ) {
        self.certificateId = certificateId
        self.vaultId = vaultId
        self.deviceId = deviceId
        self.issuedByDeviceId = issuedByDeviceId
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
        self.permissions = permissions
        self.signature = signature
    }
}
