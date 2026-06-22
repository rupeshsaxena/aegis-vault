import Foundation
import SecureVaultKit

enum VaultHomeState: Equatable {
    case loading
    case loaded([VaultObjectSummaryViewData])
    case empty(VaultHomeEmptyState)
    case error(String)
}

struct VaultObjectSummaryViewData: Equatable, Identifiable {
    let id: VaultObjectID
    let title: String
    let type: VaultObjectType
    let updatedAt: Date
    let hasThumbnail: Bool

    init(summary: VaultObjectSummary) {
        id = summary.id
        title = summary.title
        type = summary.type
        updatedAt = summary.updatedAt
        hasThumbnail = summary.type == .document || summary.type == .photo
    }
}

struct VaultHomeEmptyState: Equatable {
    let title: String
    let suggestion: String
}

enum VaultObjectTypeFilter: String, CaseIterable, Equatable, Identifiable {
    case all = "All"
    case notes = "Notes"
    case identities = "Identities"
    case cards = "Cards"
    case documents = "Documents"
    case photos = "Photos"

    var id: Self { self }

    var objectTypes: [VaultObjectType] {
        switch self {
        case .all: []
        case .notes: [.secureNote]
        case .identities: [.identity]
        case .cards: [.card]
        case .documents: [.document]
        case .photos: [.photo]
        }
    }
}
