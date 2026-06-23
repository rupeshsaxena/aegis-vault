import Observation
import SecureVaultKit
import SwiftUI

enum CardEditorMode {
    case create
    case edit(VaultObjectDetail)
}

@MainActor
@Observable
final class CardEditorViewModel {
    var data = CardEditorData()
    private(set) var isSaving = false
    private(set) var savedObjectID: VaultObjectID?
    private(set) var errorMessage: String?

    @ObservationIgnored private let mode: CardEditorMode
    @ObservationIgnored private let createUseCase: any CreateCardUsing
    @ObservationIgnored private let updateUseCase: any UpdateCardUsing

    init(mode: CardEditorMode, createUseCase: any CreateCardUsing, updateUseCase: any UpdateCardUsing) {
        self.mode = mode
        self.createUseCase = createUseCase
        self.updateUseCase = updateUseCase
        if case .edit(let detail) = mode { data = Self.data(from: detail) }
    }

    func save() async {
        data.title = data.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !data.title.isEmpty else { errorMessage = "Title is required."; return }
        guard !data.type.requiresCardNumber || !data.cardNumber.isEmpty else {
            errorMessage = "Card number is required."
            return
        }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            switch mode {
            case .create: savedObjectID = try await createUseCase.execute(data: data)
            case .edit(let detail): savedObjectID = try await updateUseCase.execute(existing: detail, data: data)
            }
        } catch {
            errorMessage = "Unable to save card."
        }
    }

    private static func data(from detail: VaultObjectDetail) -> CardEditorData {
        CardEditorData(
            title: detail.metadata.title,
            type: CardType(rawValue: detail.metadata.category ?? "") ?? .other,
            cardholderName: detail.payload.fields["cardholderName"]?.textValue ?? "",
            cardNumber: detail.payload.fields["cardNumber"]?.textValue ?? "",
            expiryMonth: detail.payload.fields["expiryMonth"]?.intValue,
            expiryYear: detail.payload.fields["expiryYear"]?.intValue,
            issuer: detail.payload.fields["issuer"]?.textValue ?? "",
            notes: detail.payload.notes ?? "",
            tags: detail.metadata.tags
        )
    }
}

struct CardEditorView: View {
    @State private var viewModel: CardEditorViewModel
    @Environment(\.dismiss) private var dismiss

    @MainActor
    init(mode: CardEditorMode, createUseCase: any CreateCardUsing, updateUseCase: any UpdateCardUsing) {
        _viewModel = State(initialValue: CardEditorViewModel(
            mode: mode, createUseCase: createUseCase, updateUseCase: updateUseCase
        ))
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $viewModel.data.title)
                Picker("Card Type", selection: $viewModel.data.type) {
                    ForEach(CardType.allCases) { Text($0.title).tag($0) }
                }
                TextField("Cardholder Name", text: $viewModel.data.cardholderName)
                SecureField("Card Number", text: $viewModel.data.cardNumber)
                    .keyboardType(.numberPad)
                    .privacySensitive()
                TextField("Issuer", text: $viewModel.data.issuer)
                TextField("Notes", text: $viewModel.data.notes, axis: .vertical)
                TextField("Tags", text: Binding(
                    get: { viewModel.data.tags.joined(separator: ", ") },
                    set: { viewModel.data.tags = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
                ))
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle("Card")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await viewModel.save() } }.disabled(viewModel.isSaving)
                }
            }
            .onChange(of: viewModel.savedObjectID) { _, id in if id != nil { dismiss() } }
        }
    }
}

extension VaultFieldValue {
    var textValue: String? {
        switch self {
        case .text(let value), .secureText(let value), .url(let value), .email(let value), .phone(let value): value
        default: nil
        }
    }

    var dateValue: Date? {
        if case .date(let value) = self { value } else { nil }
    }

    var intValue: Int? {
        if case .number(let value) = self { Int(value) } else { nil }
    }
}
