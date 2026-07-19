public enum SyncEngineEvent: Equatable, Sendable {
    case operationRecorded(SyncOperationID)
    case syncCompleted(SyncResult)
}

