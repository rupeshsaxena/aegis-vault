import Foundation

public struct VaultObjectSummary: Equatable, Codable, Sendable {
    public var id: VaultObjectID
    public var type: VaultObjectType
    public var title: String
    public var subtitle: String?
    public var tags: [String]
    public var updatedAt: Date
    public var isDeleted: Bool

    public init(
        id: VaultObjectID,
        type: VaultObjectType,
        title: String,
        subtitle: String? = nil,
        tags: [String] = [],
        updatedAt: Date,
        isDeleted: Bool = false
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.tags = tags
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
    }
}
