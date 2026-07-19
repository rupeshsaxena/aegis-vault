public protocol ConflictResolver: Sendable {
    func resolve(_ conflict: SyncConflict) -> SyncOperation
}

public struct DefaultConflictResolver: ConflictResolver {
    private let policy: ConflictResolutionPolicy

    public init(policy: ConflictResolutionPolicy = .markConflicted) {
        self.policy = policy
    }

    public func resolve(_ conflict: SyncConflict) -> SyncOperation {
        switch policy {
        case .keepLocal:
            return conflict.local
        case .keepRemote:
            return conflict.remote
        case .markConflicted:
            var operation = conflict.local
            operation.state = .conflicted
            return operation
        }
    }
}

