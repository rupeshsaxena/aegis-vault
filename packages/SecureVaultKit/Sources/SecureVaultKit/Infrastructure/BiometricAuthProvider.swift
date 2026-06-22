import Foundation

internal enum BiometricAuthResult: Equatable, Sendable {
    case success
    case cancelled
    case failed
    case unavailable
}

internal enum BiometricAuthError: Error, Equatable, Sendable {
    case unavailable
    case cancelled
    case failed
    case lockedOut
    case notEnrolled
}

internal protocol BiometricAuthProvider: Sendable {
    func canEvaluatePolicy() async -> Bool
    func authenticate(reason: String) async throws -> BiometricAuthResult
}

internal struct FakeBiometricAuthProvider: BiometricAuthProvider {
    enum Behavior: Sendable {
        case result(BiometricAuthResult)
        case error(BiometricAuthError)
    }

    private let available: Bool
    private let behavior: Behavior

    init(
        available: Bool = true,
        behavior: Behavior = .result(.success)
    ) {
        self.available = available
        self.behavior = behavior
    }

    func canEvaluatePolicy() async -> Bool {
        available
    }

    func authenticate(reason: String) async throws -> BiometricAuthResult {
        _ = reason
        switch behavior {
        case .result(let result):
            return result
        case .error(let error):
            throw error
        }
    }
}
