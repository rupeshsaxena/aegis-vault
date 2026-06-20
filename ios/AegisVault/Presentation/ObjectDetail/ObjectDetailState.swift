import Foundation
import SecureVaultKit

enum ObjectDetailState: Equatable {
    case idle
    case loading
    case loaded(ObjectDetailViewData)
    case failed(String)
    case movedToTrash
}

struct ObjectDetailViewData: Equatable {
    let id: VaultObjectID
    let title: String
    let type: VaultObjectType
    let subtitle: String?
    let tags: [String]
    let isFavorite: Bool
    var fields: [ObjectDetailFieldViewData]
    let attachments: [ObjectDetailAttachmentViewData]
    let createdAt: Date
    let updatedAt: Date
    let version: Int
}

struct ObjectDetailFieldViewData: Equatable, Identifiable {
    let id: String
    let label: String
    var value: String
    let isSensitive: Bool
    var isRevealed: Bool
}

struct ObjectDetailAttachmentViewData: Equatable, Identifiable {
    let id: BlobID
    let fileName: String
    let role: AttachmentRole
    let contentType: String
    let byteCount: Int
}
