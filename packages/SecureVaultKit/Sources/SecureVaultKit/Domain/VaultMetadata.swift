import Foundation

public struct VaultMetadata: Equatable, Codable, Sendable {
    public var title: String
    public var subtitle: String?
    public var category: String?
    public var tags: [String]
    public var isFavorite: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(
        title: String,
        subtitle: String? = nil,
        category: String? = nil,
        tags: [String] = [],
        isFavorite: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.category = category
        self.tags = tags
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
}
