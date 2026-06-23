import Observation
import SecureVaultKit
import SwiftUI

enum IdentityEditorMode {
    case create
    case edit(VaultObjectDetail)
}

@MainActor
@Observable
final class IdentityEditorViewModel {
    var data = IdentityEditorData()
    private(set) var isSaving = false
    private(set) var savedObjectID: VaultObjectID?
    private(set) var errorMessage: String?

    @ObservationIgnored private let mode: IdentityEditorMode
    @ObservationIgnored private let createUseCase: any CreateIdentityUsing
    @ObservationIgnored private let updateUseCase: any UpdateIdentityUsing

    init(
        mode: IdentityEditorMode,
        createUseCase: any CreateIdentityUsing,
        updateUseCase: any UpdateIdentityUsing
    ) {
        self.mode = mode
        self.createUseCase = createUseCase
        self.updateUseCase = updateUseCase
        if case .edit(let detail) = mode { data = Self.data(from: detail) }
    }

    func save() async {
        data.title = data.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !data.title.isEmpty else { errorMessage = "Title is required."; return }
        guard !data.type.requiresDocumentNumber || !data.documentNumber.isEmpty else {
            errorMessage = "Document number is required."
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
            errorMessage = "Unable to save identity."
        }
    }

    private static func data(from detail: VaultObjectDetail) -> IdentityEditorData {
        IdentityEditorData(
            title: detail.metadata.title,
            type: IdentityDocumentType(rawValue: detail.metadata.category ?? "") ?? .other,
            fullName: detail.payload.fields["fullName"]?.textValue ?? "",
            documentNumber: detail.payload.fields["documentNumber"]?.textValue ?? "",
            issueDate: detail.payload.fields["issueDate"]?.dateValue,
            expiryDate: detail.payload.fields["expiryDate"]?.dateValue,
            notes: detail.payload.notes ?? "",
            tags: detail.metadata.tags
        )
    }
}

struct IdentityEditorView: View {
    @State private var viewModel: IdentityEditorViewModel
    @Environment(\.dismiss) private var dismiss

    @MainActor
    init(mode: IdentityEditorMode, createUseCase: any CreateIdentityUsing, updateUseCase: any UpdateIdentityUsing) {
        _viewModel = State(initialValue: IdentityEditorViewModel(
            mode: mode, createUseCase: createUseCase, updateUseCase: updateUseCase
        ))
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $viewModel.data.title)
                Picker("Identity Type", selection: $viewModel.data.type) {
                    ForEach(IdentityDocumentType.allCases) { Text($0.title).tag($0) }
                }
                TextField("Full Name", text: $viewModel.data.fullName)
                SecureField("Document Number", text: $viewModel.data.documentNumber)
                    .privacySensitive()
                TextField("Notes", text: $viewModel.data.notes, axis: .vertical)
                TextField("Tags", text: Binding(
                    get: { viewModel.data.tags.joined(separator: ", ") },
                    set: { viewModel.data.tags = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
                ))
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle("Identity")
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
