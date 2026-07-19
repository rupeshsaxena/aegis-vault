import Foundation

public struct SyncOperation: Codable, Equatable, Sendable {
    public var id: SyncOperationID
    public var vaultId: VaultID
    public var entityType: SyncEntityType
    public var entityId: String
    public var mutationKind: SyncMutationKind
    public var state: SyncOperationState
    public var metadata: SyncMetadata
    public var attemptCount: Int
    public var lastFailure: SyncFailure?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: SyncOperationID = SyncOperationID(),
        vaultId: VaultID,
        entityType: SyncEntityType,
        entityId: String,
        mutationKind: SyncMutationKind,
        state: SyncOperationState = .pending,
        metadata: SyncMetadata,
        attemptCount: Int = 0,
        lastFailure: SyncFailure? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.vaultId = vaultId
        self.entityType = entityType
        self.entityId = entityId
        self.mutationKind = mutationKind
        self.state = state
        self.metadata = metadata
        self.attemptCount = attemptCount
        self.lastFailure = lastFailure
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

