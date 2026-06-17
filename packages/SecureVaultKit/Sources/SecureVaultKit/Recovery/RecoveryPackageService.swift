import Foundation

public struct RecoverySecret: Equatable, Sendable {
    internal let value: String

    public init(_ value: String) {
        self.value = value
    }
}

public struct RecoveryPackage: Equatable, Codable, Sendable {
    public var formatVersion: Int
    public var packageId: String
    public var vaultId: VaultID
    public var deviceId: DeviceID
    public var createdAt: Date
    public var validationProof: String

    public init(
        formatVersion: Int,
        packageId: String,
        vaultId: VaultID,
        deviceId: DeviceID,
        createdAt: Date = Date(),
        validationProof: String
    ) {
        self.formatVersion = formatVersion
        self.packageId = packageId
        self.vaultId = vaultId
        self.deviceId = deviceId
        self.createdAt = createdAt
        self.validationProof = validationProof
    }
}

public struct RecoveryValidationResult: Equatable, Sendable {
    public var isValid: Bool
    public var failures: [RecoveryValidationFailure]

    public init(isValid: Bool, failures: [RecoveryValidationFailure] = []) {
        self.isValid = isValid
        self.failures = failures
    }

    public static var success: RecoveryValidationResult {
        RecoveryValidationResult(isValid: true)
    }
}

public enum RecoveryValidationFailure: String, Equatable, Codable, Sendable {
    case emptyRecoverySecret
    case invalidValidationProof
    case unsupportedFormatVersion
}

internal protocol RecoveryPackageService: Sendable {
    func generateRecoveryPackage(
        vaultId: VaultID,
        deviceId: DeviceID,
        recoverySecret: RecoverySecret
    ) async throws -> RecoveryPackage

    func exportRecoveryPackage(_ package: RecoveryPackage) async throws -> Data
    func importRecoveryPackage(from data: Data) async throws -> RecoveryPackage

    func validateRecoveryPackage(
        _ package: RecoveryPackage,
        recoverySecret: RecoverySecret
    ) async -> RecoveryValidationResult
}

internal struct DefaultRecoveryPackageService: RecoveryPackageService {
    static let supportedFormatVersion = 1

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func generateRecoveryPackage(
        vaultId: VaultID,
        deviceId: DeviceID,
        recoverySecret: RecoverySecret
    ) async throws -> RecoveryPackage {
        try Task.checkCancellation()
        guard !recoverySecret.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw VaultError.invalidInput("Recovery secret must not be empty.")
        }
        let packageId = UUID().uuidString
        return RecoveryPackage(
            formatVersion: Self.supportedFormatVersion,
            packageId: packageId,
            vaultId: vaultId,
            deviceId: deviceId,
            createdAt: Self.jsonStableDate(),
            validationProof: Self.validationProof(
                for: recoverySecret,
                packageId: packageId,
                vaultId: vaultId
            )
        )
    }

    func exportRecoveryPackage(_ package: RecoveryPackage) async throws -> Data {
        try Task.checkCancellation()
        return try encoder.encode(package)
    }

    func importRecoveryPackage(from data: Data) async throws -> RecoveryPackage {
        try Task.checkCancellation()
        do {
            return try decoder.decode(RecoveryPackage.self, from: data)
        } catch {
            throw VaultError.invalidInput("Recovery package JSON is invalid.")
        }
    }

    func validateRecoveryPackage(
        _ package: RecoveryPackage,
        recoverySecret: RecoverySecret
    ) async -> RecoveryValidationResult {
        var failures: [RecoveryValidationFailure] = []
        if package.formatVersion != Self.supportedFormatVersion {
            failures.append(.unsupportedFormatVersion)
        }
        if recoverySecret.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            failures.append(.emptyRecoverySecret)
        } else {
            let expectedProof = Self.validationProof(
                for: recoverySecret,
                packageId: package.packageId,
                vaultId: package.vaultId
            )
            if package.validationProof != expectedProof {
                failures.append(.invalidValidationProof)
            }
        }
        return RecoveryValidationResult(isValid: failures.isEmpty, failures: failures)
    }

    private static func validationProof(
        for recoverySecret: RecoverySecret,
        packageId: String,
        vaultId: VaultID
    ) -> String {
        let material = "\(packageId)|\(vaultId.rawValue)|\(recoverySecret.value)"
        let checksum = material.utf8.reduce(UInt64(14_695_981_039_346_656_037)) { partial, byte in
            (partial ^ UInt64(byte)) &* 1_099_511_628_211
        }
        return "fake-v1-\(String(checksum, radix: 16))"
    }

    private static func jsonStableDate() -> Date {
        Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970))
    }
}
