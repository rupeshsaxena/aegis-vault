import Observation
import SecureVaultKit
import SwiftUI
import UIKit

// MARK: - Flow Bundle

struct VaultHomeFlowUseCases: Sendable {
    let listObjects: any ListVaultObjectsUsing
    let searchObjects: any SearchVaultObjectsUsing
    let createNote: any CreateSecureNoteUsing
    let getDetail: any GetObjectDetailUsing
    let updateNote: any UpdateSecureNoteUsing
    let createIdentity: any CreateIdentityUsing
    let updateIdentity: any UpdateIdentityUsing
    let createCard: any CreateCardUsing
    let updateCard: any UpdateCardUsing
    let importDocument: any ImportDocumentUsing
    let loadThumbnail: any LoadThumbnailUsing
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
    private(set) var selectedType: VaultObjectType?
    private(set) var thumbnails: [VaultObjectID: Data] = [:]
    private(set) var missingThumbnails: Set<VaultObjectID> = []
    var query = ""

    var isEmpty: Bool { !isLoading && objects.isEmpty && errorMessage == nil }

    @ObservationIgnored private let listVaultObjectsUseCase: any ListVaultObjectsUsing
    @ObservationIgnored private let searchVaultObjectsUseCase: any SearchVaultObjectsUsing

    init(
        listVaultObjectsUseCase: any ListVaultObjectsUsing,
        searchVaultObjectsUseCase: any SearchVaultObjectsUsing
    ) {
        self.listVaultObjectsUseCase = listVaultObjectsUseCase
        self.searchVaultObjectsUseCase = searchVaultObjectsUseCase
    }

    func loadObjects() async {
        isLoading = true
        errorMessage = nil
        do {
            let types = selectedType.map { [$0] } ?? []
            let filter = VaultObjectFilter(types: types)
            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                objects = try await listVaultObjectsUseCase.execute(filter: filter)
            } else {
                objects = try await searchVaultObjectsUseCase.execute(query: query, filter: filter)
            }
        } catch {
            errorMessage = "Failed to load vault: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func triggerRefresh() {
        refreshID += 1
    }

    func selectType(_ type: VaultObjectType?) async {
        selectedType = type
        await loadObjects()
    }

    func loadThumbnail(for objectID: VaultObjectID, using useCase: any LoadThumbnailUsing) async {
        guard thumbnails[objectID] == nil, !missingThumbnails.contains(objectID) else { return }
        do {
            thumbnails[objectID] = try await useCase.execute(objectID: objectID).data
        } catch {
            missingThumbnails.insert(objectID)
        }
    }
}

// MARK: - View

struct VaultHomeView: View {
    let vaultID: VaultID
    let flow: VaultHomeFlowUseCases
    @State private var viewModel: VaultHomeViewModel
    @State private var navPath: [VaultObjectID] = []
    @State private var showCreateNote = false
    @State private var showCreateIdentity = false
    @State private var showCreateCard = false
    @State private var showDocumentImport = false

    @MainActor init(vaultID: VaultID, flow: VaultHomeFlowUseCases) {
        self.vaultID = vaultID
        self.flow = flow
        _viewModel = State(initialValue: VaultHomeViewModel(
            listVaultObjectsUseCase: flow.listObjects,
            searchVaultObjectsUseCase: flow.searchObjects
        ))
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
            .searchable(text: $viewModel.query, prompt: "Search title or tags")
            .onSubmit(of: .search) { Task { await viewModel.loadObjects() } }
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
        .sheet(isPresented: $showCreateIdentity, onDismiss: { viewModel.triggerRefresh() }) {
            IdentityEditorView(mode: .create, createUseCase: flow.createIdentity, updateUseCase: flow.updateIdentity)
        }
        .sheet(isPresented: $showCreateCard, onDismiss: { viewModel.triggerRefresh() }) {
            CardEditorView(mode: .create, createUseCase: flow.createCard, updateUseCase: flow.updateCard)
        }
        .sheet(isPresented: $showDocumentImport, onDismiss: { viewModel.triggerRefresh() }) {
            DocumentImportView(vaultID: vaultID, importUseCase: flow.importDocument)
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
                HStack(spacing: 12) {
                    thumbnail(for: object)
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
            }
            .accessibilityIdentifier("objectRow-\(object.id)")
            .task(id: object.id) {
                if object.type == .document || object.type == .photo {
                    await viewModel.loadThumbnail(for: object.id, using: flow.loadThumbnail)
                }
            }
        }
        .refreshable { await viewModel.loadObjects() }
        .accessibilityIdentifier("vaultObjectList")
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("Secure Note", systemImage: "note.text") { showCreateNote = true }
                Button("Identity", systemImage: "person.text.rectangle") { showCreateIdentity = true }
                Button("Card", systemImage: "creditcard") { showCreateCard = true }
                Button("Document", systemImage: "doc.badge.plus") { showDocumentImport = true }
            } label: {
                Label("Add", systemImage: "plus")
            }
            .accessibilityIdentifier("addObjectButton")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("All") { Task { await viewModel.selectType(nil) } }
                Button("Identities") { Task { await viewModel.selectType(.identity) } }
                Button("Cards") { Task { await viewModel.selectType(.card) } }
                Button("Documents") { Task { await viewModel.selectType(.document) } }
            } label: {
                Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
            }
            .accessibilityIdentifier("objectTypeFilter")
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

    @ViewBuilder
    private func thumbnail(for object: VaultObjectSummary) -> some View {
        if let data = viewModel.thumbnails[object.id] {
            if let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipped()
                    .accessibilityIdentifier("thumbnail-\(object.id)")
            } else {
                Image(systemName: "doc.richtext.fill")
                    .frame(width: 44, height: 44)
                    .foregroundStyle(.tint)
                    .accessibilityIdentifier("thumbnail-\(object.id)")
            }
        } else {
            Image(systemName: object.type == .document ? "doc" : "lock.fill")
                .frame(width: 44, height: 44)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("thumbnailPlaceholder-\(object.id)")
        }
    }
}
