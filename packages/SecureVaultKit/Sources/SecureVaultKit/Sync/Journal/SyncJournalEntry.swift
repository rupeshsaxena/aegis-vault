import Foundation

public struct SyncJournalEntry: Codable, Equatable, Sendable {
    public var operation: SyncOperation
    public var recordedAt: Date

    public init(operation: SyncOperation, recordedAt: Date = Date()) {
        self.operation = operation
        self.recordedAt = recordedAt
    }
}

