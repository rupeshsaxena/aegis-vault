public enum RemoteSyncError: Error, Equatable, Sendable {
    case unavailable
    case rejected(String)
    case notImplemented
}

