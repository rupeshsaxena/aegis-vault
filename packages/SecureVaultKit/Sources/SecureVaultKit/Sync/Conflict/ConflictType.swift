public enum ConflictType: String, Codable, Equatable, Sendable {
    case concurrentUpdate = "concurrent_update"
    case deleteUpdate = "delete_update"
    case duplicateCreate = "duplicate_create"
}

