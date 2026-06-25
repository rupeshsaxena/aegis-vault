import SecureVaultKit
import SwiftUI

struct SecureNoteEditorView: View {
    let mode: SecureNoteEditorMode
    @ObservedObject var viewModel: SecureNoteEditorViewModel

    var body: some View {
        NavigationStack {
            form
                .navigationTitle(navigationTitle)
                .navigationBarTitleDisplayMode(.inline)
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
            Section("Title") {
                TextField("Note title", text: Binding(
                    get: { viewModel.data.title },
                    set: { viewModel.setTitle($0) }
                ))
                .autocorrectionDisabled()
                .accessibilityIdentifier("noteTitleField")
            }
            Section("Content") {
                TextEditor(text: Binding(
                    get: { viewModel.data.content },
                    set: { viewModel.setContent($0) }
                ))
                .frame(minHeight: 200)
                .accessibilityIdentifier("noteContentField")
            }
            Section("Tags") {
                TextField("Comma-separated tags", text: Binding(
                    get: { viewModel.tagsInput },
                    set: { viewModel.setTagsInput($0) }
                ))
            }
            if case .failed(let message) = viewModel.state {
                Section {
                    Text(message).foregroundStyle(.red)
                        .accessibilityIdentifier("editorError")
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { viewModel.cancel() }
                .accessibilityIdentifier("cancelEditorButton")
        }
        ToolbarItem(placement: .confirmationAction) {
            if viewModel.state == .saving {
                ProgressView()
            } else {
                Button("Save") {
                    Task { await viewModel.save() }
                }
                .disabled(viewModel.data.title.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityIdentifier("saveNoteButton")
            }
        }
    }

    private var navigationTitle: String {
        switch mode {
        case .create: "New Note"
        case .edit: "Edit Note"
        }
    }
}
