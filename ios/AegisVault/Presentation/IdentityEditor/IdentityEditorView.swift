import SwiftUI

struct IdentityEditorView: View {
    let mode: IdentityEditorMode
    @ObservedObject var viewModel: IdentityEditorViewModel

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

            Section("Identity") {
                TextField("Title", text: binding(\.title, setter: viewModel.setTitle))
                Picker("Identity Type", selection: binding(\.identityType, setter: viewModel.setIdentityType)) {
                    ForEach(IdentityDocumentType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                TextField("Full Name", text: binding(\.fullName, setter: viewModel.setFullName))
                SecureField("Document Number", text: binding(\.documentNumber, setter: viewModel.setDocumentNumber))
                    .textInputAutocapitalization(.characters)
                    .privacySensitive()
            }

            Section("Dates") {
                Toggle("Issue Date", isOn: issueDateEnabledBinding)
                if let issueDate = viewModel.data.issueDate {
                    DatePicker("Issued", selection: issueDateBinding(issueDate), displayedComponents: .date)
                }
                Toggle("Expiry Date", isOn: expiryDateEnabledBinding)
                if let expiryDate = viewModel.data.expiryDate {
                    DatePicker("Expires", selection: expiryDateBinding(expiryDate), displayedComponents: .date)
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
        _ keyPath: KeyPath<IdentityEditorViewData, Value>,
        setter: @escaping (Value) -> Void
    ) -> Binding<Value> {
        Binding(get: { viewModel.data[keyPath: keyPath] }, set: setter)
    }

    private var tagsBinding: Binding<String> {
        Binding(get: { viewModel.tagsInput }, set: viewModel.setTagsInput)
    }

    private var issueDateEnabledBinding: Binding<Bool> {
        Binding(get: { viewModel.data.issueDate != nil }, set: viewModel.setIssueDateEnabled)
    }

    private func issueDateBinding(_ fallback: Date) -> Binding<Date> {
        Binding(get: { viewModel.data.issueDate ?? fallback }, set: viewModel.setIssueDate)
    }

    private var expiryDateEnabledBinding: Binding<Bool> {
        Binding(get: { viewModel.data.expiryDate != nil }, set: viewModel.setExpiryDateEnabled)
    }

    private func expiryDateBinding(_ fallback: Date) -> Binding<Date> {
        Binding(get: { viewModel.data.expiryDate ?? fallback }, set: viewModel.setExpiryDate)
    }

    private var navigationTitle: String {
        switch mode {
        case .create: "New Identity"
        case .edit: "Edit Identity"
        }
    }
}
