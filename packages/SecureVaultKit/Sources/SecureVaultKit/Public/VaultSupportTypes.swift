import Foundation

public enum VaultError: Error, Equatable, Sendable {
    case vaultNotFound(VaultID)
    case vaultAlreadyExists
    case objectNotFound(VaultObjectID)
    case locked
    case authenticationFailed
    case thumbnailNotFound(VaultObjectID)
    case invalidInput(String)
    case unsupported(String)
    case unsupportedOperation(String)
}

public enum UnlockMethod: Equatable, Codable, Sendable {
    case passphrase
    case biometric
    case passkey
    case recoverySecret(String)
    case recoveryPackage

    internal var fakeIdentifier: String {
        switch self {
        case .passphrase:
            "passphrase"
        case .biometric:
            "biometric"
        case .passkey:
            "passkey"
        case .recoverySecret:
            "recoverySecret"
        case .recoveryPackage:
            "recoveryPackage"
        }
    }
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
    public var objectId: VaultObjectID?
    public var metadata: VaultMetadata?
    public var payload: VaultPayload?

    public init(
        objectId: VaultObjectID? = nil,
        metadata: VaultMetadata? = nil,
        payload: VaultPayload? = nil
    ) {
        self.objectId = objectId
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
    public var fileURL: URL?
    public var fileName: String
    public var contentType: String
    public var data: Data?

    public init(
        fileURL: URL,
        contentType: String,
        fileName: String? = nil
    ) {
        self.fileURL = fileURL
        self.fileName = fileName ?? fileURL.lastPathComponent
        self.contentType = contentType
        self.data = nil
    }

    public init(
        fileName: String,
        contentType: String,
        data: Data
    ) {
        self.fileURL = nil
        self.fileName = fileName
        self.contentType = contentType
        self.data = data
    }
}

public struct ImportedDocumentMetadata: Equatable, Codable, Sendable {
    public var fileName: String
    public var contentType: String
    public var byteCount: Int
    public var fileExtension: String
    public var importedAt: Date

    public init(
        fileName: String,
        contentType: String,
        byteCount: Int,
        fileExtension: String,
        importedAt: Date = Date()
    ) {
        self.fileName = fileName
        self.contentType = contentType
        self.byteCount = byteCount
        self.fileExtension = fileExtension
        self.importedAt = importedAt
    }
}

public struct DocumentImportResult: Equatable, Sendable {
    public var objectId: VaultObjectID
    public var attachment: VaultAttachment
    public var thumbnailAttachment: VaultAttachment?
    public var previewAttachment: VaultAttachment?
    public var metadata: ImportedDocumentMetadata
    public var attachments: [VaultAttachment] {
        [attachment, thumbnailAttachment, previewAttachment].compactMap { $0 }
    }

    public init(
        objectId: VaultObjectID,
        attachment: VaultAttachment,
        thumbnailAttachment: VaultAttachment? = nil,
        previewAttachment: VaultAttachment? = nil,
        metadata: ImportedDocumentMetadata
    ) {
        self.objectId = objectId
        self.attachment = attachment
        self.thumbnailAttachment = thumbnailAttachment
        self.previewAttachment = previewAttachment
        self.metadata = metadata
    }
}
