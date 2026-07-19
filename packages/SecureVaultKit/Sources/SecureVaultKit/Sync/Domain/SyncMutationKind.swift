public enum SyncMutationKind: String, Codable, CaseIterable, Sendable {
    case create
    case update
    case delete
    case restore
    case purge
}

