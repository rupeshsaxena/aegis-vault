import Observation
import SecureVaultKit
import SwiftUI

// MARK: - Mode

enum SecureNoteEditorMode {
    case create
    case edit(VaultObjectDetail)
}

// MARK: - View Model

@MainActor
@Observable
final class SecureNoteEditorViewModel {
    var title: String = ""
    var notes: String = ""
    var isSaving = false
    var errorMessage: String?
    var savedObjectID: VaultObjectID?

    private(set) var mode: SecureNoteEditorMode

    var canSave: Bool {
        !isSaving && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @ObservationIgnored private let createUseCase: any CreateSecureNoteUsing
    @ObservationIgnored private let updateUseCase: any UpdateSecureNoteUsing

    init(
        mode: SecureNoteEditorMode,
        createUseCase: any CreateSecureNoteUsing,
        updateUseCase: any UpdateSecureNoteUsing
    ) {
        self.mode = mode
        self.createUseCase = createUseCase
        self.updateUseCase = updateUseCase

        if case .edit(let detail) = mode {
            title = detail.metadata.title
            notes = detail.payload.notes ?? ""
        }
    }

    func save() async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        isSaving = true
        errorMessage = nil

        do {
            switch mode {
            case .create:
                let objectID = try await createUseCase.execute(
                    title: trimmedTitle,
                    notes: notes.isEmpty ? nil : notes
                )
                savedObjectID = objectID
            case .edit(let detail):
                try await updateUseCase.execute(
                    id: detail.id,
                    title: trimmedTitle,
                    notes: notes.isEmpty ? nil : notes
                )
                savedObjectID = detail.id
            }
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }

        isSaving = false
    }
}

// MARK: - View

struct SecureNoteEditorView: View {
    @State private var viewModel: SecureNoteEditorViewModel
    @Environment(\.dismiss) private var dismiss

    @MainActor init(
        mode: SecureNoteEditorMode,
        createUseCase: any CreateSecureNoteUsing,
        updateUseCase: any UpdateSecureNoteUsing
    ) {
        _viewModel = State(initialValue: SecureNoteEditorViewModel(
            mode: mode,
            createUseCase: createUseCase,
            updateUseCase: updateUseCase
        ))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Note title", text: $viewModel.title)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("noteTitleField")
                }
                Section("Content") {
                    TextEditor(text: $viewModel.notes)
                        .frame(minHeight: 200)
                        .accessibilityIdentifier("noteContentField")
                }
                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("editorError")
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("cancelEditorButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            Task { await viewModel.save() }
                        }
                        .disabled(!viewModel.canSave)
                        .accessibilityIdentifier("saveNoteButton")
                    }
                }
            }
            .onChange(of: viewModel.savedObjectID) { _, id in
                if id != nil { dismiss() }
            }
        }
    }

    private var navigationTitle: String {
        switch viewModel.mode {
        case .create: "New Note"
        case .edit: "Edit Note"
        }
    }
}
