import Combine
import Foundation
import SecureVaultKit

@MainActor
final class CardEditorViewModel: ObservableObject {
    @Published private(set) var state: CardEditorState = .idle
    @Published private(set) var data = CardEditorViewData()
    @Published private(set) var tagsInput = ""
    @Published private(set) var route: AppRoute?

    private let createCardUseCase: any CreateCardUsing
    private let updateCardUseCase: any UpdateCardUsing
    private let getObjectDetailUseCase: any GetObjectDetailUsing
    private var mode: CardEditorMode?
    private var existingDetail: VaultObjectDetail?

    init(
        mode: CardEditorMode? = nil,
        createCardUseCase: any CreateCardUsing,
        updateCardUseCase: any UpdateCardUsing,
        getObjectDetailUseCase: any GetObjectDetailUsing
    ) {
        self.mode = mode
        self.createCardUseCase = createCardUseCase
        self.updateCardUseCase = updateCardUseCase
        self.getObjectDetailUseCase = getObjectDetailUseCase
        if case .create = mode {
            state = .editing
        }
    }

    func prepare(mode: CardEditorMode) async {
        guard self.mode != mode || state == .idle else { return }
        self.mode = mode
        data = CardEditorViewData()
        tagsInput = ""
        existingDetail = nil

        switch mode {
        case .create:
            state = .editing
        case .edit(let objectID):
            state = .idle
            do {
                let detail = try await getObjectDetailUseCase.execute(id: objectID)
                guard detail.type == .card else {
                    state = .failed("This item cannot be edited as a card.")
                    return
                }
                existingDetail = detail
                data = Self.editorData(from: detail)
                tagsInput = detail.metadata.tags.joined(separator: ", ")
                state = .editing
            } catch {
                state = .failed(Self.userMessage(for: error))
            }
        }
    }

    func setTitle(_ value: String) { update { $0.title = value } }
    func setCardType(_ value: CardType) { update { $0.cardType = value } }
    func setCardholderName(_ value: String) { update { $0.cardholderName = value } }
    func setCardNumber(_ value: String) { update { $0.cardNumber = value } }
    func setExpiryMonth(_ value: Int?) { update { $0.expiryMonth = value } }
    func setExpiryYear(_ value: Int?) { update { $0.expiryYear = value } }
    func setIssuer(_ value: String) { update { $0.issuer = value } }
    func setNotes(_ value: String) { update { $0.notes = value } }

    func setTagsInput(_ value: String) {
        tagsInput = value
        restoreEditingState()
    }

    func save() async {
        var input = data
        input.title = input.title.trimmingCharacters(in: .whitespacesAndNewlines)
        input.cardNumber = input.cardNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        input.tags = parsedTags

        guard !input.title.isEmpty else {
            state = .failed("Title is required.")
            return
        }
        guard !input.cardType.requiresCardNumber || !input.cardNumber.isEmpty else {
            state = .failed("Card number is required.")
            return
        }
        guard let mode else {
            state = .failed("Unable to save card.")
            return
        }

        state = .saving
        do {
            let objectID: VaultObjectID
            switch mode {
            case .create:
                objectID = try await createCardUseCase.execute(data: input)
            case .edit:
                guard let existingDetail else {
                    state = .failed("Unable to save card.")
                    return
                }
                objectID = try await updateCardUseCase.execute(existing: existingDetail, data: input)
            }
            state = .saved(objectID)
            route = .objectDetail(objectID)
        } catch {
            state = .failed(Self.userMessage(for: error))
        }
    }

    func cancel() {
        switch mode {
        case .create(let vaultID): route = .vaultHome(vaultID)
        case .edit(let objectID): route = .objectDetail(objectID)
        case nil: break
        }
    }

    func clearRoute() {
        route = nil
    }

    static func userMessage(for error: Error) -> String {
        if case VaultError.locked = error {
            return "Your vault is locked."
        }
        return "Unable to save card."
    }

    private func update(_ mutation: (inout CardEditorViewData) -> Void) {
        mutation(&data)
        restoreEditingState()
    }

    private func restoreEditingState() {
        if case .failed = state {
            state = .editing
        }
    }

    private var parsedTags: [String] {
        var seen = Set<String>()
        return tagsInput
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }

    private static func editorData(from detail: VaultObjectDetail) -> CardEditorViewData {
        let fields = detail.payload.fields
        let typeRawValue: String?
        if case .text(let value) = fields["cardType"] {
            typeRawValue = value
        } else {
            typeRawValue = detail.metadata.category
        }

        let cardholderName: String
        if case .text(let value) = fields["cardholderName"] { cardholderName = value } else { cardholderName = "" }
        let cardNumber: String
        if case .secureText(let value) = fields["cardNumber"] { cardNumber = value } else { cardNumber = "" }
        let expiryMonth: Int?
        if case .number(let value) = fields["expiryMonth"] { expiryMonth = Int(value) } else { expiryMonth = nil }
        let expiryYear: Int?
        if case .number(let value) = fields["expiryYear"] { expiryYear = Int(value) } else { expiryYear = nil }
        let issuer: String
        if case .text(let value) = fields["issuer"] { issuer = value } else { issuer = "" }

        return CardEditorViewData(
            title: detail.metadata.title,
            cardType: typeRawValue.flatMap(CardType.init(rawValue:)) ?? .other,
            cardholderName: cardholderName,
            cardNumber: cardNumber,
            expiryMonth: expiryMonth,
            expiryYear: expiryYear,
            issuer: issuer,
            notes: detail.payload.notes ?? "",
            tags: detail.metadata.tags
        )
    }
}
