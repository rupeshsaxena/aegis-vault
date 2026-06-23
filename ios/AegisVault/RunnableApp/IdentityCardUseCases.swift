import Foundation
import SecureVaultKit

enum IdentityDocumentType: String, CaseIterable, Identifiable, Sendable {
    case passport
    case aadhaar
    case pan
    case driverLicense
    case other

    var id: Self { self }
    var requiresDocumentNumber: Bool { self != .other }

    var displayName: String {
        switch self {
        case .passport: "Passport"
        case .aadhaar: "Aadhaar"
        case .pan: "PAN"
        case .driverLicense: "Driver License"
        case .other: "Other"
        }
    }
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

enum CardType: String, CaseIterable, Identifiable, Sendable {
    case creditCard
    case debitCard
    case insuranceCard
    case membershipCard
    case other

    var id: Self { self }
    var requiresCardNumber: Bool { self == .creditCard || self == .debitCard }

    var displayName: String {
        switch self {
        case .creditCard: "Credit Card"
        case .debitCard: "Debit Card"
        case .insuranceCard: "Insurance Card"
        case .membershipCard: "Membership Card"
        case .other: "Other"
        }
    }
}

struct CardEditorViewData: Equatable, Sendable {
    var title = ""
    var cardType: CardType = .creditCard
    var cardholderName = ""
    var cardNumber = ""
    var expiryMonth: Int?
    var expiryYear: Int?
    var issuer = ""
    var notes = ""
    var tags: [String] = []
}

protocol CreateIdentityUsing: Sendable {
    func execute(data: IdentityEditorViewData) async throws -> VaultObjectID
}

protocol UpdateIdentityUsing: Sendable {
    func execute(existing: VaultObjectDetail, data: IdentityEditorViewData) async throws -> VaultObjectID
}

protocol CreateCardUsing: Sendable {
    func execute(data: CardEditorViewData) async throws -> VaultObjectID
}

protocol UpdateCardUsing: Sendable {
    func execute(existing: VaultObjectDetail, data: CardEditorViewData) async throws -> VaultObjectID
}

protocol SearchVaultUsing: Sendable {
    func execute(query: String, filter: VaultObjectFilter) async throws -> [VaultObjectSummary]
}

struct CreateIdentityUseCase: CreateIdentityUsing {
    let vaultEngine: any VaultEngine

    func execute(data: IdentityEditorViewData) async throws -> VaultObjectID {
        try await vaultEngine.createObject(VaultObjectDraft(
            type: .identity,
            metadata: VaultMetadata(title: data.title, category: data.identityType.rawValue, tags: data.tags),
            payload: VaultPayload(notes: data.notes, fields: identityFields(data))
        ))
    }
}

struct UpdateIdentityUseCase: UpdateIdentityUsing {
    let vaultEngine: any VaultEngine

    func execute(existing: VaultObjectDetail, data: IdentityEditorViewData) async throws -> VaultObjectID {
        guard existing.type == .identity else { throw VaultError.invalidInput("Expected an identity object.") }
        var metadata = existing.metadata
        metadata.title = data.title
        metadata.category = data.identityType.rawValue
        metadata.tags = data.tags
        var payload = existing.payload
        payload.notes = data.notes
        payload.fields = identityFields(data)
        return try await vaultEngine.updateObject(
            VaultObjectUpdate(objectId: existing.id, metadata: metadata, payload: payload)
        ).id
    }
}

struct CreateCardUseCase: CreateCardUsing {
    let vaultEngine: any VaultEngine

    func execute(data: CardEditorViewData) async throws -> VaultObjectID {
        try await vaultEngine.createObject(VaultObjectDraft(
            type: .card,
            metadata: VaultMetadata(title: data.title, category: data.cardType.rawValue, tags: data.tags),
            payload: VaultPayload(notes: data.notes, fields: cardFields(data))
        ))
    }
}

struct UpdateCardUseCase: UpdateCardUsing {
    let vaultEngine: any VaultEngine

    func execute(existing: VaultObjectDetail, data: CardEditorViewData) async throws -> VaultObjectID {
        guard existing.type == .card else { throw VaultError.invalidInput("Expected a card object.") }
        var metadata = existing.metadata
        metadata.title = data.title
        metadata.category = data.cardType.rawValue
        metadata.tags = data.tags
        var payload = existing.payload
        payload.notes = data.notes
        payload.fields = cardFields(data)
        return try await vaultEngine.updateObject(
            VaultObjectUpdate(objectId: existing.id, metadata: metadata, payload: payload)
        ).id
    }
}

struct SearchVaultUseCase: SearchVaultUsing {
    let vaultEngine: any VaultEngine

    func execute(query: String, filter: VaultObjectFilter) async throws -> [VaultObjectSummary] {
        try await vaultEngine.searchObjects(query: query, filter: filter)
    }
}

private func identityFields(_ data: IdentityEditorViewData) -> [String: VaultFieldValue] {
    var fields: [String: VaultFieldValue] = [
        "identityType": .text(data.identityType.rawValue),
        "fullName": .text(data.fullName),
        "documentNumber": .secureText(data.documentNumber)
    ]
    fields["issueDate"] = data.issueDate.map(VaultFieldValue.date)
    fields["expiryDate"] = data.expiryDate.map(VaultFieldValue.date)
    return fields
}

private func cardFields(_ data: CardEditorViewData) -> [String: VaultFieldValue] {
    var fields: [String: VaultFieldValue] = [
        "cardType": .text(data.cardType.rawValue),
        "cardholderName": .text(data.cardholderName),
        "cardNumber": .secureText(data.cardNumber),
        "issuer": .text(data.issuer)
    ]
    fields["expiryMonth"] = data.expiryMonth.map { .number(Double($0)) }
    fields["expiryYear"] = data.expiryYear.map { .number(Double($0)) }
    return fields
}
