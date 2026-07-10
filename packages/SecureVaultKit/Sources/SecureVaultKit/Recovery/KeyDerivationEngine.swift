import CryptoKit
import Foundation

public enum KeyDerivationAlgorithm: String, Codable, Sendable {
    case argon2id
}

public struct KeyDerivationParameters: Equatable, Codable, Sendable {
    public var algorithm: KeyDerivationAlgorithm
    public var memoryCost: Int
    public var iterations: Int
    public var parallelism: Int
    public var salt: Data
    public var outputLength: Int
    public var version: Int

    public init(
        algorithm: KeyDerivationAlgorithm = .argon2id,
        memoryCost: Int,
        iterations: Int,
        parallelism: Int,
        salt: Data,
        outputLength: Int,
        version: Int = 1
    ) {
        self.algorithm = algorithm
        self.memoryCost = memoryCost
        self.iterations = iterations
        self.parallelism = parallelism
        self.salt = salt
        self.outputLength = outputLength
        self.version = version
    }
}

public struct DerivedKeyMaterial: Equatable, Sendable {
    public var keyId: KeyIdentifier
    public var data: Data
    public var parameters: KeyDerivationParameters

    public init(
        keyId: KeyIdentifier,
        data: Data,
        parameters: KeyDerivationParameters
    ) {
        self.keyId = keyId
        self.data = data
        self.parameters = parameters
    }
}

public protocol KeyDerivationEngine: Sendable {
    func deriveKey(
        from secret: RecoverySecret,
        parameters: KeyDerivationParameters
    ) async throws -> DerivedKeyMaterial
}

public struct FakeKeyDerivationEngine: KeyDerivationEngine {
    public init() {}

    public func deriveKey(
        from secret: RecoverySecret,
        parameters: KeyDerivationParameters
    ) async throws -> DerivedKeyMaterial {
        try Task.checkCancellation()
        guard parameters.outputLength > 0 else {
            throw VaultError.invalidInput("Derived key output length must be positive.")
        }
        let normalizedSecret = secret.normalizedForDerivation
        guard !normalizedSecret.isEmpty else {
            throw VaultError.invalidInput("Recovery secret must not be empty.")
        }

        var output = Data()
        var counter = 0
        while output.count < parameters.outputLength {
            var input = Data()
            input.append(Data(normalizedSecret.utf8))
            input.append(parameters.salt)
            input.append(Data("\(parameters.version)|\(parameters.memoryCost)|\(parameters.iterations)|\(parameters.parallelism)|\(counter)".utf8))
            output.append(Data(SHA256.hash(data: input)))
            counter += 1
        }

        let keyData = Data(output.prefix(parameters.outputLength))
        return DerivedKeyMaterial(
            keyId: KeyIdentifier("recovery-key-\(Self.keyDigest(for: keyData))"),
            data: keyData,
            parameters: parameters
        )
    }

    private static func keyDigest(for data: Data) -> String {
        Data(SHA256.hash(data: data))
            .prefix(8)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

public struct RealKeyDerivationEngine: KeyDerivationEngine {
    public init() {}

    public func deriveKey(
        from secret: RecoverySecret,
        parameters: KeyDerivationParameters
    ) async throws -> DerivedKeyMaterial {
        try Task.checkCancellation()
        _ = secret
        _ = parameters
        throw CryptoError.notImplemented
    }
}
