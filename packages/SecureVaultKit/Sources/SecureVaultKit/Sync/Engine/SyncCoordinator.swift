public actor SyncCoordinator {
    private let engine: any SyncEngine
    private var isRunning = false

    public init(engine: any SyncEngine) {
        self.engine = engine
    }

    public func synchronize(context: SyncExecutionContext) async throws -> SyncResult {
        guard !isRunning else {
            return SyncResult()
        }
        isRunning = true
        defer { isRunning = false }
        return try await engine.synchronize(context: context)
    }
}

