public enum VaultObjectType: String, CaseIterable, Codable, Sendable {
    case secureNote
    case identity
    case card
    case document
    case photo
}
