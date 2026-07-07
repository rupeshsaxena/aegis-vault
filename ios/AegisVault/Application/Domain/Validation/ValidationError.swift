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

    var userMessage: String {
        switch self {
        case .validation(.missingTitle):
            "Title is required."
        case .validation(.missingRequiredField("documentNumber")):
            "Document number is required."
        case .validation(.missingRequiredField("cardNumber")):
            "Card number is required."
        case .validation(.missingRequiredField(let field)):
            "\(field) is required."
        case .validation:
            "Unable to save item."
        }
    }
}
