import Foundation

public struct SyncMetadata: Codable, Equatable, Sendable {
    public var vaultId: VaultID
    public var entityId: String
    public var deviceId: DeviceID
    public var objectVersion: Int?
    public var versionVector: VersionVector
    public var encryptedRecordDigest: String?
    public var updatedAt: Date

    public init(
        vaultId: VaultID,
        entityId: String,
        deviceId: DeviceID,
        objectVersion: Int? = nil,
        versionVector: VersionVector = VersionVector(),
        encryptedRecordDigest: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.vaultId = vaultId
        self.entityId = entityId
        self.deviceId = deviceId
        self.objectVersion = objectVersion
        self.versionVector = versionVector
        self.encryptedRecordDigest = encryptedRecordDigest
        self.updatedAt = updatedAt
    }
}

