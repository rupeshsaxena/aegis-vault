import Observation
import SecureVaultKit
import SwiftUI

// MARK: - Flow Bundle

struct VaultHomeFlowUseCases: Sendable {
    let listObjects: any ListVaultObjectsUsing
    let createNote: any CreateSecureNoteUsing
    let getDetail: any GetObjectDetailUsing
    let updateNote: any UpdateSecureNoteUsing
    let moveToTrash: any MoveObjectToTrashUsing
    let restoreFromTrash: any RestoreFromTrashUsing
}

// MARK: - View Model

@MainActor
@Observable
final class VaultHomeViewModel {
    private(set) var objects: [VaultObjectSummary] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var refreshID: Int = 0

    var isEmpty: Bool { !isLoading && objects.isEmpty && errorMessage == nil }

    @ObservationIgnored private let listVaultObjectsUseCase: any ListVaultObjectsUsing

    init(listVaultObjectsUseCase: any ListVaultObjectsUsing) {
        self.listVaultObjectsUseCase = listVaultObjectsUseCase
    }

    func loadObjects() async {
        isLoading = true
        errorMessage = nil
        do {
            objects = try await listVaultObjectsUseCase.execute(filter: VaultObjectFilter())
        } catch {
            errorMessage = "Failed to load vault: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func triggerRefresh() {
        refreshID += 1
    }
}

// MARK: - View

struct VaultHomeView: View {
    let vaultID: VaultID
    let flow: VaultHomeFlowUseCases
    @State private var viewModel: VaultHomeViewModel
    @State private var navPath: [VaultObjectID] = []
    @State private var showCreateNote = false

    @MainActor init(vaultID: VaultID, flow: VaultHomeFlowUseCases) {
        self.vaultID = vaultID
        self.flow = flow
        _viewModel = State(initialValue: VaultHomeViewModel(listVaultObjectsUseCase: flow.listObjects))
    }

    var body: some View {
        NavigationStack(path: $navPath) {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                } else if let error = viewModel.errorMessage {
                    ContentUnavailableView(
                        "Unable to Load Vault",
                        systemImage: "exclamationmark.lock",
                        description: Text(error)
                    )
                } else if viewModel.isEmpty {
                    emptyState
                } else {
                    objectList
                }
            }
            .navigationTitle("AegisVault")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbarContent }
            .navigationDestination(for: VaultObjectID.self) { objectID in
                ObjectDetailView(
                    objectID: objectID,
                    flow: flow,
                    onMovedToTrash: { viewModel.triggerRefresh() }
                )
            }
        }
        .task(id: viewModel.refreshID) {
            await viewModel.loadObjects()
        }
        .sheet(isPresented: $showCreateNote, onDismiss: {
            viewModel.triggerRefresh()
        }) {
            SecureNoteEditorView(
                mode: .create,
                createUseCase: flow.createNote,
                updateUseCase: flow.updateNote
            )
        }
        .accessibilityIdentifier("vaultHomeTitle")
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Secrets Yet",
            systemImage: "lock.open",
            description: Text("Tap the pencil icon to create your first note.")
        )
        .accessibilityIdentifier("vaultEmptyState")
    }

    private var objectList: some View {
        List(viewModel.objects, id: \.id) { object in
            Button {
                navPath.append(object.id)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(object.title)
                        .font(.body)
                        .foregroundStyle(.primary)
                    if let subtitle = object.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .accessibilityIdentifier("objectRow-\(object.id)")
        }
        .refreshable { await viewModel.loadObjects() }
        .accessibilityIdentifier("vaultObjectList")
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showCreateNote = true
            } label: {
                Label("New Note", systemImage: "square.and.pencil")
            }
            .accessibilityIdentifier("newNoteButton")
        }
        ToolbarItem(placement: .topBarLeading) {
            NavigationLink {
                TrashView(flow: flow, onRestored: { viewModel.triggerRefresh() })
            } label: {
                Label("Trash", systemImage: "trash")
            }
            .accessibilityIdentifier("trashButton")
        }
    }
}
