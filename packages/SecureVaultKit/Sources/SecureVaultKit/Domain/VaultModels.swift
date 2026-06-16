import Foundation

public struct Vault: Equatable, Codable, Sendable {
    public var id: VaultID
    public var name: String
    public var createdAt: Date
    public var updatedAt: Date
    public var primaryDeviceID: DeviceID?

    public init(
        id: VaultID = VaultID(),
        name: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        primaryDeviceID: DeviceID? = nil
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.primaryDeviceID = primaryDeviceID
    }
}

public enum VaultItemKind: String, CaseIterable, Codable, Sendable {
    case secureNote
    case identity
    case paymentCard
    case document
    case photo
}

public struct VaultItem: Equatable, Codable, Sendable {
    public var id: VaultItemID
    public var vaultID: VaultID
    public var title: String
    public var kind: VaultItemKind
    public var payload: VaultItemPayload
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(
        id: VaultItemID = VaultItemID(),
        vaultID: VaultID,
        title: String,
        kind: VaultItemKind,
        payload: VaultItemPayload,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.vaultID = vaultID
        self.title = title
        self.kind = kind
        self.payload = payload
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    public var isDeleted: Bool {
        deletedAt != nil
    }
}

public enum VaultItemPayload: Equatable, Codable, Sendable {
    case secureNote(SecureNote)
    case identity(IdentityRecord)
    case paymentCard(PaymentCard)
    case document(VaultDocument)
    case photo(VaultPhoto)

    public var kind: VaultItemKind {
        switch self {
        case .secureNote:
            .secureNote
        case .identity:
            .identity
        case .paymentCard:
            .paymentCard
        case .document:
            .document
        case .photo:
            .photo
        }
    }
}

public struct SecureNote: Equatable, Codable, Sendable {
    public var body: String

    public init(body: String) {
        self.body = body
    }
}

public struct IdentityRecord: Equatable, Codable, Sendable {
    public var fullName: String
    public var email: String?
    public var phone: String?
    public var addressLines: [String]

    public init(fullName: String, email: String? = nil, phone: String? = nil, addressLines: [String] = []) {
        self.fullName = fullName
        self.email = email
        self.phone = phone
        self.addressLines = addressLines
    }
}

public struct PaymentCard: Equatable, Codable, Sendable {
    public var cardholderName: String
    public var network: String?
    public var last4: String
    public var expirationMonth: Int?
    public var expirationYear: Int?

    public init(
        cardholderName: String,
        network: String? = nil,
        last4: String,
        expirationMonth: Int? = nil,
        expirationYear: Int? = nil
    ) {
        self.cardholderName = cardholderName
        self.network = network
        self.last4 = last4
        self.expirationMonth = expirationMonth
        self.expirationYear = expirationYear
    }
}

public struct VaultDocument: Equatable, Codable, Sendable {
    public var blob: BlobDescriptor
    public var preview: PreviewDescriptor?

    public init(blob: BlobDescriptor, preview: PreviewDescriptor? = nil) {
        self.blob = blob
        self.preview = preview
    }
}

public struct VaultPhoto: Equatable, Codable, Sendable {
    public var blob: BlobDescriptor
    public var thumbnail: PreviewDescriptor?

    public init(blob: BlobDescriptor, thumbnail: PreviewDescriptor? = nil) {
        self.blob = blob
        self.thumbnail = thumbnail
    }
}
