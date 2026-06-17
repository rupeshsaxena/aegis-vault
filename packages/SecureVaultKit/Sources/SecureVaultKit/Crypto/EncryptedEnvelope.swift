import Foundation

public struct EncryptedEnvelope: Codable, Equatable, Sendable {
    public var version: Int
    public var algorithm: CryptoAlgorithm
    public var keyId: KeyIdentifier
    public var nonce: Data
    public var ciphertext: Data

    public init(
        version: Int,
        algorithm: CryptoAlgorithm,
        keyId: KeyIdentifier,
        nonce: Data,
        ciphertext: Data
    ) {
        self.version = version
        self.algorithm = algorithm
        self.keyId = keyId
        self.nonce = nonce
        self.ciphertext = ciphertext
    }

    internal init(algorithm: String, keyReference: String, ciphertextReference: String) {
        self.init(
            version: 1,
            algorithm: .xChaCha20Poly1305,
            keyId: KeyIdentifier(keyReference),
            nonce: Data(),
            ciphertext: Data(ciphertextReference.utf8)
        )
    }

    internal var keyReference: String {
        keyId.rawValue
    }

    internal var ciphertextReference: String {
        String(data: ciphertext, encoding: .utf8) ?? ciphertext.base64EncodedString()
    }
}
