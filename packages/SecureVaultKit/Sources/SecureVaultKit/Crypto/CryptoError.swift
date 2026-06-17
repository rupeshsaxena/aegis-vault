public enum CryptoError: Error, Equatable, Sendable {
    case notImplemented
    case invalidEnvelope
    case invalidKeyMaterial
    case invalidWrappedKey
}
