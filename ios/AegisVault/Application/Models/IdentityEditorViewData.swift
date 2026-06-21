import Foundation

enum IdentityDocumentType: String, CaseIterable, Equatable, Hashable, Sendable, Identifiable {
    case passport
    case aadhaar
    case pan
    case driverLicense
    case other

    var id: Self { self }

    var displayName: String {
        switch self {
        case .passport: "Passport"
        case .aadhaar: "Aadhaar"
        case .pan: "PAN"
        case .driverLicense: "Driver License"
        case .other: "Other"
        }
    }

    var requiresDocumentNumber: Bool { self != .other }
}

struct IdentityEditorViewData: Equatable, Sendable {
    var title = ""
    var identityType: IdentityDocumentType = .passport
    var fullName = ""
    var documentNumber = ""
    var issueDate: Date?
    var expiryDate: Date?
    var notes = ""
    var tags: [String] = []
}
