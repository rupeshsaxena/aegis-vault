public enum SyncEntityType: String, Codable, CaseIterable, Sendable {
    case vault
    case secureNote = "secure_note"
    case identity
    case card
    case document
    case attachment
    case blob
    case thumbnail
    case preview
    case device
}

extension SyncEntityType {
    init(objectType: VaultObjectType) {
        switch objectType {
        case .secureNote:
            self = .secureNote
        case .identity:
            self = .identity
        case .card:
            self = .card
        case .document:
            self = .document
        case .photo:
            self = .blob
        }
    }
}

