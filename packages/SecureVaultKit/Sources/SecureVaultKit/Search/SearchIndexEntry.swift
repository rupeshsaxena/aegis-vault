import Foundation

internal struct SearchIndexEntry: Equatable, Sendable {
    var objectId: VaultObjectID
    var vaultId: VaultID?
    var type: VaultObjectType
    var title: String
    var subtitle: String?
    var tags: [String]
    var updatedAt: Date
    var isDeleted: Bool
    var version: Int
    var searchableText: String

    init(
        objectId: VaultObjectID,
        vaultId: VaultID? = nil,
        type: VaultObjectType,
        title: String,
        subtitle: String? = nil,
        tags: [String] = [],
        updatedAt: Date,
        isDeleted: Bool = false,
        version: Int = 1
    ) {
        self.objectId = objectId
        self.vaultId = vaultId
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.tags = tags
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
        self.version = version
        self.searchableText = ([title] + tags + [type.rawValue])
            .joined(separator: " ")
            .lowercased()
    }

    init(summary: VaultObjectSummary) {
        self.init(
            objectId: summary.id,
            vaultId: summary.vaultId,
            type: summary.type,
            title: summary.title,
            subtitle: summary.subtitle,
            tags: summary.tags,
            updatedAt: summary.updatedAt,
            isDeleted: summary.isDeleted,
            version: summary.version
        )
    }

    var summary: VaultObjectSummary {
        VaultObjectSummary(
            id: objectId,
            vaultId: vaultId,
            type: type,
            title: title,
            subtitle: subtitle,
            tags: tags,
            updatedAt: updatedAt,
            isDeleted: isDeleted,
            version: version
        )
    }
}
