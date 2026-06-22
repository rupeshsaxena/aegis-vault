import SwiftUI

struct SecureNoteEditorView: View {
    let mode: SecureNoteEditorMode
    @ObservedObject var viewModel: SecureNoteEditorViewModel

    var body: some View {
        NavigationStack {
            Form {
                if case .failed(let message) = viewModel.state {
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
                Section("Note") {
                    TextField("Title", text: titleBinding)
                    TextEditor(text: contentBinding)
                        .frame(minHeight: 220)
                        .privacySensitive()
                }
                Section("Tags") {
                    TextField("Comma-separated tags", text: tagsBinding)
                        .textInputAutocapitalization(.never)
                }
            }
            .disabled(viewModel.state == .saving)
            .overlay { if viewModel.state == .saving { ProgressView() } }
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
            .task(id: mode) { await viewModel.prepare(mode: mode) }
        }
    }

    private var titleBinding: Binding<String> {
        Binding(get: { viewModel.data.title }, set: viewModel.setTitle)
    }

    private var contentBinding: Binding<String> {
        Binding(get: { viewModel.data.content }, set: viewModel.setContent)
    }

    private var tagsBinding: Binding<String> {
        Binding(get: { viewModel.tagsInput }, set: viewModel.setTagsInput)
    }

    private var navigationTitle: String {
        switch mode {
        case .create: "New Secure Note"
        case .edit: "Edit Secure Note"
        }
    }
}
