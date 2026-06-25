import SecureVaultKit
import SwiftUI

struct VaultHomeView: View {
    let vaultID: VaultID
    @ObservedObject var viewModel: VaultHomeViewModel
    @State private var searchText: String = ""

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("AegisVault")
                .navigationBarTitleDisplayMode(.large)
                .searchable(text: $searchText, prompt: "Search title or tags")
                .onSubmit(of: .search) { Task { await viewModel.search(query: searchText) } }
                .onChange(of: searchText) { _, query in Task { await viewModel.search(query: query) } }
                .toolbar { toolbarItems }
                .task { await viewModel.loadObjects() }
                .refreshable { await viewModel.loadObjects() }
        }
        .accessibilityIdentifier("vaultHomeTitle")
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
        case .error(let message):
            ContentUnavailableView(
                "Unable to Load Vault",
                systemImage: "exclamationmark.lock",
                description: Text(message)
            )
        case .empty(let emptyState):
            ContentUnavailableView(
                emptyState.title,
                systemImage: "lock.open",
                description: Text(emptyState.suggestion)
            )
            .accessibilityIdentifier("vaultEmptyState")
        case .loaded(let items):
            objectList(items)
        }
    }

    private func objectList(_ items: [VaultObjectSummaryViewData]) -> some View {
        List(items) { item in
            Button {
                viewModel.selectObject(id: item.id)
            } label: {
                HStack(spacing: 12) {
                    ThumbnailImageView(
                        state: viewModel.thumbnailStates[item.id] ?? .idle,
                        fallbackSystemImage: systemImage(for: item.type)
                    )
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title).font(.body).foregroundStyle(.primary)
                        Text(item.type.displayName)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .accessibilityIdentifier("objectRow-\(item.id)")
            .task(id: item.id) {
                if item.hasThumbnail {
                    await viewModel.loadThumbnail(for: item.id)
                }
            }
        }
        .accessibilityIdentifier("vaultObjectList")
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("Secure Note", systemImage: "note.text") {
                    viewModel.addSecureNote(to: vaultID)
                }
                Button("Identity", systemImage: "person.text.rectangle") {
                    viewModel.addIdentity(to: vaultID)
                }
                Button("Card", systemImage: "creditcard") {
                    viewModel.addCard(to: vaultID)
                }
                Button("Document", systemImage: "doc.badge.plus") {
                    viewModel.importDocument(into: vaultID)
                }
            } label: {
                Label("Add", systemImage: "plus")
            }
            .accessibilityIdentifier("addObjectButton")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("All") { Task { await viewModel.clearFilter() } }
                Button("Notes") { Task { await viewModel.selectFilter(.notes) } }
                Button("Identities") { Task { await viewModel.selectFilter(.identities) } }
                Button("Cards") { Task { await viewModel.selectFilter(.cards) } }
                Button("Documents") { Task { await viewModel.selectFilter(.documents) } }
            } label: {
                Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
            }
            .accessibilityIdentifier("objectTypeFilter")
        }
        ToolbarItem(placement: .topBarLeading) {
            Button {
                viewModel.showTrash(for: vaultID)
            } label: {
                Label("Trash", systemImage: "trash")
            }
            .accessibilityIdentifier("trashButton")
        }
        ToolbarItem(placement: .topBarLeading) {
            Button {
                viewModel.showSettings(for: vaultID)
            } label: {
                Label("Settings", systemImage: "gear")
            }
        }
    }

    private func systemImage(for type: VaultObjectType) -> String {
        switch type {
        case .secureNote: return "note.text"
        case .identity: return "person.text.rectangle"
        case .card: return "creditcard"
        case .document: return "doc"
        case .photo: return "photo"
        default: return "lock.fill"
        }
    }
}

extension VaultObjectType {
    var displayName: String {
        switch self {
        case .secureNote: return "Secure Note"
        case .identity: return "Identity"
        case .card: return "Card"
        case .document: return "Document"
        case .photo: return "Photo"
        default: return "Item"
        }
    }
}
