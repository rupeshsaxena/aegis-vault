import SecureVaultKit
import SwiftUI

struct CardEditorView: View {
    let mode: CardEditorMode
    @ObservedObject var viewModel: CardEditorViewModel

    var body: some View {
        NavigationStack {
            form
                .navigationTitle("Card")
                .toolbar { toolbarItems }
                .task { await viewModel.prepare(mode: mode) }
        }
    }

    @ViewBuilder
    private var form: some View {
        switch viewModel.state {
        case .idle:
            ProgressView()
        case .editing, .saving, .saved, .failed:
            editorForm
        }
    }

    private var editorForm: some View {
        Form {
            TextField("Title", text: Binding(
                get: { viewModel.data.title },
                set: { viewModel.setTitle($0) }
            ))
            Picker("Card Type", selection: Binding(
                get: { viewModel.data.cardType },
                set: { viewModel.setCardType($0) }
            )) {
                ForEach(CardType.allCases) { Text($0.displayName).tag($0) }
            }
            TextField("Cardholder Name", text: Binding(
                get: { viewModel.data.cardholderName },
                set: { viewModel.setCardholderName($0) }
            ))
            SecureField("Card Number", text: Binding(
                get: { viewModel.data.cardNumber },
                set: { viewModel.setCardNumber($0) }
            ))
            .keyboardType(.numberPad)
            .privacySensitive()
            TextField("Issuer", text: Binding(
                get: { viewModel.data.issuer },
                set: { viewModel.setIssuer($0) }
            ))
            TextField("Notes", text: Binding(
                get: { viewModel.data.notes },
                set: { viewModel.setNotes($0) }
            ), axis: .vertical)
            TextField("Tags (comma-separated)", text: Binding(
                get: { viewModel.tagsInput },
                set: { viewModel.setTagsInput($0) }
            ))
            if case .failed(let message) = viewModel.state {
                Text(message).foregroundStyle(.red)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { viewModel.cancel() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
                Task { await viewModel.save() }
            }
            .disabled(viewModel.state == .saving)
        }
    }
}
