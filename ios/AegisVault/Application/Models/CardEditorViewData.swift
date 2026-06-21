enum CardType: String, CaseIterable, Equatable, Hashable, Sendable, Identifiable {
    case creditCard
    case debitCard
    case insuranceCard
    case membershipCard
    case other

    var id: Self { self }

    var displayName: String {
        switch self {
        case .creditCard: "Credit Card"
        case .debitCard: "Debit Card"
        case .insuranceCard: "Insurance Card"
        case .membershipCard: "Membership Card"
        case .other: "Other"
        }
    }

    var requiresCardNumber: Bool {
        self == .creditCard || self == .debitCard
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
