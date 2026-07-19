public enum ConflictResolutionPolicy: String, Codable, Sendable {
    case keepLocal
    case keepRemote
    case markConflicted
}

