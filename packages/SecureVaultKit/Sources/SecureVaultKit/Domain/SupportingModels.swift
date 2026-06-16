import Foundation

public struct BlobDescriptor: Equatable, Codable, Sendable {
    public var id: BlobID
    public var contentType: String
    public var byteCount: Int
    public var encryptedDigest: String?

    public init(
        id: BlobID = BlobID(),
        contentType: String,
        byteCount: Int,
        encryptedDigest: String? = nil
    ) {
        self.id = id
        self.contentType = contentType
        self.byteCount = byteCount
        self.encryptedDigest = encryptedDigest
    }
}

public struct PreviewDescriptor: Equatable, Codable, Sendable {
    public var blobID: BlobID
    public var pixelWidth: Int
    public var pixelHeight: Int

    public init(blobID: BlobID, pixelWidth: Int, pixelHeight: Int) {
        self.blobID = blobID
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }
}

public struct DeviceIdentity: Equatable, Codable, Sendable {
    public var id: DeviceID
    public var displayName: String
    public var publicKeyFingerprint: String
    public var enrolledAt: Date

    public init(
        id: DeviceID = DeviceID(),
        displayName: String,
        publicKeyFingerprint: String,
        enrolledAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.publicKeyFingerprint = publicKeyFingerprint
        self.enrolledAt = enrolledAt
    }
}

public struct RecoveryPackage: Equatable, Codable, Sendable {
    public var id: String
    public var vaultID: VaultID
    public var createdAt: Date
    public var hint: String?

    public init(id: String = UUID().uuidString, vaultID: VaultID, createdAt: Date = Date(), hint: String? = nil) {
        self.id = id
        self.vaultID = vaultID
        self.createdAt = createdAt
        self.hint = hint
    }
}

public enum VaultEventKind: String, Codable, Sendable {
    case vaultCreated
    case itemCreated
    case itemUpdated
    case itemMovedToTrash
    case itemRestored
    case itemPurged
    case deviceEnrolled
    case recoveryPackageCreated
}

public struct VaultEvent: Equatable, Codable, Sendable {
    public var id: EventID
    public var vaultID: VaultID
    public var kind: VaultEventKind
    public var itemID: VaultItemID?
    public var occurredAt: Date
    public var metadata: [String: String]

    public init(
        id: EventID = EventID(),
        vaultID: VaultID,
        kind: VaultEventKind,
        itemID: VaultItemID? = nil,
        occurredAt: Date = Date(),
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.vaultID = vaultID
        self.kind = kind
        self.itemID = itemID
        self.occurredAt = occurredAt
        self.metadata = metadata
    }
}

public struct TrashPolicy: Equatable, Sendable {
    public static let defaultRetentionDays = 30

    public var retentionDays: Int

    public init(retentionDays: Int = Self.defaultRetentionDays) {
        self.retentionDays = retentionDays
    }
}
