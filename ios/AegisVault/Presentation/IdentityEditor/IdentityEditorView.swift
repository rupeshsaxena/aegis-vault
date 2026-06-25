import SecureVaultKit
import SwiftUI

struct IdentityEditorView: View {
    let mode: IdentityEditorMode
    @ObservedObject var viewModel: IdentityEditorViewModel

    var body: some View {
        NavigationStack {
            form
                .navigationTitle("Identity")
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
            Picker("Identity Type", selection: Binding(
                get: { viewModel.data.identityType },
                set: { viewModel.setIdentityType($0) }
            )) {
                ForEach(IdentityDocumentType.allCases) { Text($0.displayName).tag($0) }
            }
            TextField("Full Name", text: Binding(
                get: { viewModel.data.fullName },
                set: { viewModel.setFullName($0) }
            ))
            SecureField("Document Number", text: Binding(
                get: { viewModel.data.documentNumber },
                set: { viewModel.setDocumentNumber($0) }
            ))
            .privacySensitive()
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
