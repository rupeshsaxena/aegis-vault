import Foundation
import SecureVaultKit

struct DefaultErrorMapper: ErrorMapper {
    func appError(from error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }

        if let serviceError = error as? ApplicationServiceError {
            switch serviceError {
            case .validation(let validationError):
                return .validation(validationError)
            }
        }

        if let validationError = error as? ValidationError {
            return .validation(validationError)
        }

        if let vaultError = error as? VaultError {
            return appError(from: vaultError)
        }

        return .unknown
    }

    func userMessage(for error: Error) -> UserMessage {
        userMessage(for: error, fallback: Self.defaultFallback)
    }

    func userMessage(for error: Error, fallback: UserMessage) -> UserMessage {
        if let vaultError = error as? VaultError,
           let message = userMessage(for: vaultError, fallback: fallback) {
            return message
        }
        return userMessage(for: appError(from: error), fallback: fallback)
    }

    private func appError(from vaultError: VaultError) -> AppError {
        switch vaultError {
        case .locked:
            .locked
        case .vaultNotFound, .objectNotFound, .thumbnailNotFound:
            .notFound
        case .authenticationFailed,
             .authenticationCancelled,
             .biometricUnavailable,
             .biometricLockedOut,
             .biometricNotEnrolled:
            .permissionDenied
        case .invalidInput:
            .validation(.invalidField("input"))
        case .unsupported, .unsupportedOperation:
            .importFailure
        default:
            .unknown
        }
    }

    private func userMessage(for appError: AppError, fallback: UserMessage) -> UserMessage {
        switch appError {
        case .validation(let validationError):
            validationMessage(for: validationError, fallback: fallback)
        case .locked:
            UserMessage(
                title: "Vault Locked",
                message: "Your vault is locked.",
                recoverySuggestion: "Unlock your vault and try again."
            )
        case .notFound:
            UserMessage(
                title: "Not Found",
                message: "The requested item could not be found."
            )
        case .permissionDenied:
            UserMessage(
                title: "Authentication Failed",
                message: "Authentication failed. Please try again."
            )
        case .storageFailure:
            UserMessage(
                title: "Unable to Save",
                message: "Unable to save your changes."
            )
        case .importFailure:
            UserMessage(
                title: "Import Failed",
                message: "Unable to import document."
            )
        case .recoveryFailure:
            UserMessage(
                title: "Recovery Failed",
                message: "Unable to complete the recovery request."
            )
        case .unknown:
            fallback
        }
    }

    private func userMessage(for vaultError: VaultError, fallback: UserMessage) -> UserMessage? {
        switch vaultError {
        case .locked:
            return UserMessage(
                title: "Vault Locked",
                message: "Your vault is locked.",
                recoverySuggestion: "Unlock your vault and try again."
            )
        case .authenticationFailed:
            return UserMessage(title: "Authentication Failed", message: "Authentication failed. Please try again.")
        case .biometricUnavailable, .biometricNotEnrolled:
            return UserMessage(title: "Biometric Unavailable", message: "Biometric unlock is unavailable.")
        case .authenticationCancelled:
            return UserMessage(title: "Unlock Cancelled", message: "Unlock was cancelled.")
        case .biometricLockedOut:
            return UserMessage(
                title: "Biometric Locked",
                message: "Biometric authentication is locked. Use device passcode."
            )
        case .vaultNotFound:
            return UserMessage(title: "Vault Not Found", message: "No vault was found on this device.")
        case .objectNotFound:
            return UserMessage(title: "Item Not Found", message: "This item could not be found.")
        case .unsupported, .unsupportedOperation:
            return UserMessage(title: "Unsupported File", message: "This file type is not supported.")
        case .invalidInput:
            return UserMessage(title: "Invalid Input", message: fallback.message)
        default:
            return nil
        }
    }

    private func validationMessage(
        for validationError: ValidationError,
        fallback: UserMessage
    ) -> UserMessage {
        switch validationError {
        case .missingTitle:
            UserMessage(title: "Missing Title", message: "Title is required.")
        case .missingRequiredField("documentNumber"):
            UserMessage(title: "Missing Document Number", message: "Document number is required.")
        case .missingRequiredField("cardNumber"):
            UserMessage(title: "Missing Card Number", message: "Card number is required.")
        case .missingRequiredField(let field):
            UserMessage(title: "Missing Information", message: "\(field) is required.")
        case .invalidField:
            UserMessage(title: "Invalid Information", message: fallback.message)
        case .unsupportedType:
            UserMessage(title: "Unsupported Item", message: fallback.message)
        case .invalidState:
            UserMessage(title: "Unable to Continue", message: fallback.message)
        }
    }

    private static let defaultFallback = UserMessage(
        title: "Something Went Wrong",
        message: "Unable to complete the request."
    )
}
