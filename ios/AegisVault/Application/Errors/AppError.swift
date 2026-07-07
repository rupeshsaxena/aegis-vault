import Foundation

enum AppError: Error, Equatable, Sendable {
    case validation(ValidationError)
    case locked
    case notFound
    case permissionDenied
    case storageFailure
    case importFailure
    case recoveryFailure
    case unknown
}
