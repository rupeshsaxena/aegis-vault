import Foundation

enum ValidationError: Error, Equatable, Sendable {
    case missingTitle
    case missingRequiredField(String)
    case invalidField(String)
    case unsupportedType(String)
    case invalidState(String)
}

enum ApplicationServiceError: Error, Equatable, Sendable {
    case validation(ValidationError)
}
