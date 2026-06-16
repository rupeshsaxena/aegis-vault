import Foundation

public struct FakeCryptoProvider: VaultCryptoProvider {
    public static let algorithm = "fake.noop.v1"

    public init() {}

    public func encrypt(_ plaintext: Data, context: String) async throws -> EncryptedPayload {
        EncryptedPayload(
            ciphertext: plaintext,
            nonce: Data(context.utf8),
            algorithm: Self.algorithm
        )
    }

    public func decrypt(_ payload: EncryptedPayload, context: String) async throws -> Data {
        guard payload.algorithm == Self.algorithm else {
            throw SecureVaultError.unsupportedOperation("FakeCryptoProvider only decrypts fake payloads.")
        }
        return payload.ciphertext
    }
}
