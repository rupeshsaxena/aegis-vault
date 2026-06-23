import Observation
import SecureVaultKit
import SwiftUI

// MARK: - View Model

@MainActor
@Observable
final class ObjectDetailViewModel {
    private(set) var detail: VaultObjectDetail?
    private(set) var isLoading = false
    private(set) var isMovedToTrash = false
    private(set) var errorMessage: String?

    @ObservationIgnored private let objectID: VaultObjectID
    @ObservationIgnored private let getDetailUseCase: any GetObjectDetailUsing
    @ObservationIgnored private let moveToTrashUseCase: any MoveObjectToTrashUsing

    init(
        objectID: VaultObjectID,
        getDetailUseCase: any GetObjectDetailUsing,
        moveToTrashUseCase: any MoveObjectToTrashUsing
    ) {
        self.objectID = objectID
        self.getDetailUseCase = getDetailUseCase
        self.moveToTrashUseCase = moveToTrashUseCase
    }

    func loadDetail() async {
        isLoading = true
        errorMessage = nil
        do {
            detail = try await getDetailUseCase.execute(id: objectID)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func moveToTrash() async {
        do {
            try await moveToTrashUseCase.execute(id: objectID)
            isMovedToTrash = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - View

struct ObjectDetailView: View {
    let flow: VaultHomeFlowUseCases
    let onMovedToTrash: () -> Void
    @State private var viewModel: ObjectDetailViewModel
    @State private var showEditSheet = false
    @Environment(\.dismiss) private var dismiss

    @MainActor init(
        objectID: VaultObjectID,
        flow: VaultHomeFlowUseCases,
        onMovedToTrash: @escaping () -> Void
    ) {
        self.flow = flow
        self.onMovedToTrash = onMovedToTrash
        _viewModel = State(initialValue: ObjectDetailViewModel(
            objectID: objectID,
            getDetailUseCase: flow.getDetail,
            moveToTrashUseCase: flow.moveToTrash
        ))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else if let detail = viewModel.detail {
                detailContent(detail)
            } else if let error = viewModel.errorMessage {
                ContentUnavailableView(
                    "Unable to Load",
                    systemImage: "exclamationmark.circle",
                    description: Text(error)
                )
            }
        }
        .navigationTitle(viewModel.detail?.metadata.title ?? "Note")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit") { showEditSheet = true }
                        .accessibilityIdentifier("editNoteButton")
                    Divider()
                    Button("Move to Trash", role: .destructive) {
                        Task { await viewModel.moveToTrash() }
                    }
                    .accessibilityIdentifier("moveToTrashButton")
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityIdentifier("noteOptionsMenu")
            }
        }
        .task { await viewModel.loadDetail() }
        .sheet(isPresented: $showEditSheet, onDismiss: {
            Task { await viewModel.loadDetail() }
        }) {
            if let detail = viewModel.detail {
                SecureNoteEditorView(
                    mode: .edit(detail),
                    createUseCase: flow.createNote,
                    updateUseCase: flow.updateNote
                )
            }
        }
        .onChange(of: viewModel.isMovedToTrash) { _, moved in
            if moved {
                onMovedToTrash()
                dismiss()
            }
        }
    }

    @ViewBuilder
    private func detailContent(_ detail: VaultObjectDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let notes = detail.payload.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Text(notes)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("noteContent")
                    }
                    .padding(.horizontal)
                } else {
                    ContentUnavailableView(
                        "No Content",
                        systemImage: "note.text",
                        description: Text("This note has no content.")
                    )
                }
            }
            .padding(.vertical)
        }
        .accessibilityIdentifier("noteDetailView")
    }
}
