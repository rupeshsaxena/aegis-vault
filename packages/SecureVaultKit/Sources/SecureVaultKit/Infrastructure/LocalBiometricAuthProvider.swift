#if canImport(LocalAuthentication)
import LocalAuthentication

internal struct LocalBiometricAuthProvider: BiometricAuthProvider {
    init() {}

    func canEvaluatePolicy() async -> Bool {
        LAContext().canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: nil
        )
    }

    func authenticate(reason: String) async throws -> BiometricAuthResult {
        let context = LAContext()
        var evaluationError: NSError?
        guard context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &evaluationError
        ) else {
            throw Self.map(error: evaluationError)
        }

        do {
            let authenticated = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            return authenticated ? .success : .failed
        } catch {
            throw Self.map(error: error as NSError)
        }
    }

    private static func map(error: NSError?) -> BiometricAuthError {
        guard let error,
              error.domain == LAError.errorDomain,
              let code = LAError.Code(rawValue: error.code) else {
            return .unavailable
        }
        switch code {
        case .userCancel, .appCancel, .systemCancel:
            return .cancelled
        case .biometryLockout:
            return .lockedOut
        case .biometryNotEnrolled:
            return .notEnrolled
        case .biometryNotAvailable:
            return .unavailable
        default:
            return .failed
        }
    }
}
#else
internal struct LocalBiometricAuthProvider: BiometricAuthProvider {
    init() {}

    func canEvaluatePolicy() async -> Bool {
        false
    }

    func authenticate(reason: String) async throws -> BiometricAuthResult {
        _ = reason
        throw BiometricAuthError.unavailable
    }
}
#endif
