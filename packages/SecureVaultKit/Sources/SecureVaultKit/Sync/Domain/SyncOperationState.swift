public enum SyncOperationState: String, Codable, CaseIterable, Sendable {
    case pending
    case inFlight = "in_flight"
    case completed
    case failed
    case conflicted
}

