import Foundation

public struct VaultThumbnail: Equatable, Sendable {
    public let objectId: VaultObjectID
    public let data: Data
    public let contentType: String
    public let createdAt: Date?

    public init(
        objectId: VaultObjectID,
        data: Data,
        contentType: String,
        createdAt: Date? = nil
    ) {
        self.objectId = objectId
        self.data = data
        self.contentType = contentType
        self.createdAt = createdAt
    }
}
