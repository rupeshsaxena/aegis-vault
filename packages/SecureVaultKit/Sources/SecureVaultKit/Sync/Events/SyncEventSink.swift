public protocol SyncEventSink: Sendable {
    func emit(_ event: SyncEngineEvent) async throws
}

