public struct SyncFailure: Codable, Equatable, Error, Sendable {
    public var code: String
    public var safeMessage: String

    public init(code: String, safeMessage: String) {
        self.code = code
        self.safeMessage = safeMessage
    }

    public static let cancelled = SyncFailure(
        code: "cancelled",
        safeMessage: "Synchronization was cancelled."
    )
}

