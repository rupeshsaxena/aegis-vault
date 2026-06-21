import Foundation
import SwiftUI

struct CardEditorView: View {
    let mode: CardEditorMode
    @ObservedObject var viewModel: CardEditorViewModel

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .idle:
                    ProgressView()
                case .saving:
                    editorForm
                        .disabled(true)
                        .overlay { ProgressView() }
                case .saved:
                    ProgressView()
                case .editing, .failed:
                    editorForm
                }
            }
            .navigationTitle(navigationTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { viewModel.cancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await viewModel.save() } }
                        .disabled(viewModel.state == .saving)
                }
            }
            .task(id: mode) {
                await viewModel.prepare(mode: mode)
            }
        }
    }

    private var editorForm: some View {
        Form {
            if case .failed(let message) = viewModel.state {
                Section {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }

            Section("Card") {
                TextField("Title", text: binding(\.title, setter: viewModel.setTitle))
                Picker("Card Type", selection: binding(\.cardType, setter: viewModel.setCardType)) {
                    ForEach(CardType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                TextField("Cardholder Name", text: binding(\.cardholderName, setter: viewModel.setCardholderName))
                SecureField("Card Number", text: binding(\.cardNumber, setter: viewModel.setCardNumber))
                    .privacySensitive()
                TextField("Issuer", text: binding(\.issuer, setter: viewModel.setIssuer))
            }

            Section("Expiry") {
                Picker("Month", selection: expiryMonthBinding) {
                    Text("None").tag(Int?.none)
                    ForEach(1...12, id: \.self) { month in
                        Text(month.formatted()).tag(Optional(month))
                    }
                }
                Picker("Year", selection: expiryYearBinding) {
                    Text("None").tag(Int?.none)
                    ForEach(expiryYears, id: \.self) { year in
                        Text(year.formatted(.number.grouping(.never))).tag(Optional(year))
                    }
                }
            }

            Section("Notes") {
                TextEditor(text: binding(\.notes, setter: viewModel.setNotes))
                    .frame(minHeight: 120)
            }

            Section("Tags") {
                TextField("Comma-separated tags", text: tagsBinding)
                    .textInputAutocapitalization(.never)
            }
        }
    }

    private func binding<Value>(
        _ keyPath: KeyPath<CardEditorViewData, Value>,
        setter: @escaping (Value) -> Void
    ) -> Binding<Value> {
        Binding(get: { viewModel.data[keyPath: keyPath] }, set: setter)
    }

    private var tagsBinding: Binding<String> {
        Binding(get: { viewModel.tagsInput }, set: viewModel.setTagsInput)
    }

    private var expiryMonthBinding: Binding<Int?> {
        Binding(get: { viewModel.data.expiryMonth }, set: viewModel.setExpiryMonth)
    }

    private var expiryYearBinding: Binding<Int?> {
        Binding(get: { viewModel.data.expiryYear }, set: viewModel.setExpiryYear)
    }

    private var expiryYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array(2000...(currentYear + 30))
    }

    private var navigationTitle: String {
        switch mode {
        case .create: "New Card"
        case .edit: "Edit Card"
        }
    }
}
