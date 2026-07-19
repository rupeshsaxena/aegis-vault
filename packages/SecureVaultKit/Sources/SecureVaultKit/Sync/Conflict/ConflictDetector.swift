public protocol ConflictDetector: Sendable {
    func detect(local: SyncOperation, remote: SyncOperation) -> SyncConflict?
}

public struct VersionVectorConflictDetector: ConflictDetector {
    public init() {}

    public func detect(local: SyncOperation, remote: SyncOperation) -> SyncConflict? {
        guard local.vaultId == remote.vaultId,
              local.entityType == remote.entityType,
              local.entityId == remote.entityId else {
            return nil
        }
        guard local.metadata.versionVector.isConcurrent(with: remote.metadata.versionVector) else {
            return nil
        }
        if local.mutationKind == .delete || remote.mutationKind == .delete {
            return SyncConflict(local: local, remote: remote, type: .deleteUpdate)
        }
        if local.mutationKind == .create && remote.mutationKind == .create {
            return SyncConflict(local: local, remote: remote, type: .duplicateCreate)
        }
        return SyncConflict(local: local, remote: remote, type: .concurrentUpdate)
    }
}

