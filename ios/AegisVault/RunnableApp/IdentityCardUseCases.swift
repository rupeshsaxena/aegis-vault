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

    var title: String {
        switch self {
        case .passport: "Passport"
        case .aadhaar: "Aadhaar"
        case .pan: "PAN"
        case .driverLicense: "Driver License"
        case .other: "Other"
        }
    }
}

struct IdentityEditorData: Equatable, Sendable {
    var title = ""
    var type: IdentityDocumentType = .passport
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

    var title: String {
        switch self {
        case .creditCard: "Credit Card"
        case .debitCard: "Debit Card"
        case .insuranceCard: "Insurance Card"
        case .membershipCard: "Membership Card"
        case .other: "Other"
        }
    }
}

struct CardEditorData: Equatable, Sendable {
    var title = ""
    var type: CardType = .creditCard
    var cardholderName = ""
    var cardNumber = ""
    var expiryMonth: Int?
    var expiryYear: Int?
    var issuer = ""
    var notes = ""
    var tags: [String] = []
}

protocol CreateIdentityUsing: Sendable {
    func execute(data: IdentityEditorData) async throws -> VaultObjectID
}

protocol UpdateIdentityUsing: Sendable {
    func execute(existing: VaultObjectDetail, data: IdentityEditorData) async throws -> VaultObjectID
}

protocol CreateCardUsing: Sendable {
    func execute(data: CardEditorData) async throws -> VaultObjectID
}

protocol UpdateCardUsing: Sendable {
    func execute(existing: VaultObjectDetail, data: CardEditorData) async throws -> VaultObjectID
}

protocol SearchVaultObjectsUsing: Sendable {
    func execute(query: String, filter: VaultObjectFilter) async throws -> [VaultObjectSummary]
}

struct CreateIdentityUseCase: CreateIdentityUsing {
    let vaultEngine: any VaultEngine

    func execute(data: IdentityEditorData) async throws -> VaultObjectID {
        try await vaultEngine.createObject(VaultObjectDraft(
            type: .identity,
            metadata: VaultMetadata(title: data.title, category: data.type.rawValue, tags: data.tags),
            payload: VaultPayload(notes: data.notes, fields: identityFields(data))
        ))
    }
}

struct UpdateIdentityUseCase: UpdateIdentityUsing {
    let vaultEngine: any VaultEngine

    func execute(existing: VaultObjectDetail, data: IdentityEditorData) async throws -> VaultObjectID {
        guard existing.type == .identity else { throw VaultError.invalidInput("Expected an identity object.") }
        var metadata = existing.metadata
        metadata.title = data.title
        metadata.category = data.type.rawValue
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

    func execute(data: CardEditorData) async throws -> VaultObjectID {
        try await vaultEngine.createObject(VaultObjectDraft(
            type: .card,
            metadata: VaultMetadata(title: data.title, category: data.type.rawValue, tags: data.tags),
            payload: VaultPayload(notes: data.notes, fields: cardFields(data))
        ))
    }
}

struct UpdateCardUseCase: UpdateCardUsing {
    let vaultEngine: any VaultEngine

    func execute(existing: VaultObjectDetail, data: CardEditorData) async throws -> VaultObjectID {
        guard existing.type == .card else { throw VaultError.invalidInput("Expected a card object.") }
        var metadata = existing.metadata
        metadata.title = data.title
        metadata.category = data.type.rawValue
        metadata.tags = data.tags
        var payload = existing.payload
        payload.notes = data.notes
        payload.fields = cardFields(data)
        return try await vaultEngine.updateObject(
            VaultObjectUpdate(objectId: existing.id, metadata: metadata, payload: payload)
        ).id
    }
}

struct SearchVaultObjectsUseCase: SearchVaultObjectsUsing {
    let vaultEngine: any VaultEngine

    func execute(query: String, filter: VaultObjectFilter) async throws -> [VaultObjectSummary] {
        try await vaultEngine.searchObjects(query: query, filter: filter)
    }
}

private func identityFields(_ data: IdentityEditorData) -> [String: VaultFieldValue] {
    var fields: [String: VaultFieldValue] = [
        "identityType": .text(data.type.rawValue),
        "fullName": .text(data.fullName),
        "documentNumber": .secureText(data.documentNumber)
    ]
    fields["issueDate"] = data.issueDate.map(VaultFieldValue.date)
    fields["expiryDate"] = data.expiryDate.map(VaultFieldValue.date)
    return fields
}

private func cardFields(_ data: CardEditorData) -> [String: VaultFieldValue] {
    var fields: [String: VaultFieldValue] = [
        "cardType": .text(data.type.rawValue),
        "cardholderName": .text(data.cardholderName),
        "cardNumber": .secureText(data.cardNumber),
        "issuer": .text(data.issuer)
    ]
    fields["expiryMonth"] = data.expiryMonth.map { .number(Double($0)) }
    fields["expiryYear"] = data.expiryYear.map { .number(Double($0)) }
    return fields
}
