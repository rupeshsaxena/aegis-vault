import Foundation

public enum VaultError: Error, Equatable, Sendable {
    case vaultNotFound(VaultID)
    case vaultAlreadyExists
    case objectNotFound(VaultObjectID)
    case locked
    case invalidInput(String)
    case unsupported(String)
    case unsupportedOperation(String)
}

public enum UnlockMethod: String, CaseIterable, Codable, Sendable {
    case passphrase
    case biometric
    case passkey
    case recoveryPackage
}

public struct VaultCreationConfig: Equatable, Codable, Sendable {
    public var name: String
    public var deviceID: DeviceID
    public var unlockMethod: UnlockMethod

    public init(
        name: String,
        deviceID: DeviceID,
        unlockMethod: UnlockMethod
    ) {
        self.name = name
        self.deviceID = deviceID
        self.unlockMethod = unlockMethod
    }
}

public struct VaultObjectUpdate: Equatable, Codable, Sendable {
    public var metadata: VaultMetadata?
    public var payload: VaultPayload?

    public init(
        metadata: VaultMetadata? = nil,
        payload: VaultPayload? = nil
    ) {
        self.metadata = metadata
        self.payload = payload
    }
}

public struct VaultObjectFilter: Equatable, Codable, Sendable {
    public var types: [VaultObjectType]
    public var query: String?
    public var tags: [String]
    public var includeDeleted: Bool

    public init(
        types: [VaultObjectType] = [],
        query: String? = nil,
        tags: [String] = [],
        includeDeleted: Bool = false
    ) {
        self.types = types
        self.query = query
        self.tags = tags
        self.includeDeleted = includeDeleted
    }
}

public struct DocumentImportInput: Equatable, Sendable {
    public var fileName: String
    public var contentType: String
    public var data: Data

    public init(
        fileName: String,
        contentType: String,
        data: Data
    ) {
        self.fileName = fileName
        self.contentType = contentType
        self.data = data
    }
}
