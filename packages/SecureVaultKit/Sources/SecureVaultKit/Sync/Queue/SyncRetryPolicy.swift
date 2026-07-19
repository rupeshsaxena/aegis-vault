public struct SyncRetryPolicy: Codable, Equatable, Sendable {
    public var maxAttempts: Int
    public var baseDelaySeconds: Double

    public init(maxAttempts: Int = 5, baseDelaySeconds: Double = 1) {
        self.maxAttempts = max(1, maxAttempts)
        self.baseDelaySeconds = max(0, baseDelaySeconds)
    }
}

