import Foundation

public struct WrappedKey: Codable, Equatable, Sendable {
    public var keyId: KeyIdentifier
    public var wrappingKeyId: KeyIdentifier
    public var wrappedData: Data
    public var algorithm: CryptoAlgorithm
    internal var wrappedByDeviceId: DeviceID?

    public init(
        keyId: KeyIdentifier,
        wrappingKeyId: KeyIdentifier,
        wrappedData: Data,
        algorithm: CryptoAlgorithm
    ) {
        self.keyId = keyId
        self.wrappingKeyId = wrappingKeyId
        self.wrappedData = wrappedData
        self.algorithm = algorithm
        self.wrappedByDeviceId = nil
    }

    internal init(
        keyReference: String,
        wrappedByDeviceId: DeviceID? = nil,
        wrappingKeyReference: String? = nil
    ) {
        self.keyId = KeyIdentifier(keyReference)
        self.wrappingKeyId = KeyIdentifier(wrappingKeyReference ?? wrappedByDeviceId?.rawValue ?? "unknown-wrapping-key")
        self.wrappedData = Data(keyReference.utf8)
        self.algorithm = .xChaCha20Poly1305
        self.wrappedByDeviceId = wrappedByDeviceId
    }

    internal var keyReference: String {
        keyId.rawValue
    }

    internal var wrappingKeyReference: String? {
        wrappingKeyId.rawValue
    }
}
