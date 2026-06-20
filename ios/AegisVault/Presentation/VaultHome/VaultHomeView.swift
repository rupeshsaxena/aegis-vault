import SecureVaultKit
import SwiftUI

struct VaultHomeView: View {
    let vaultID: VaultID
    @ObservedObject var viewModel: VaultHomeViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filters
                content
            }
            .navigationTitle("Vault")
            .searchable(text: searchBinding, prompt: "Search your vault")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        viewModel.addItem(to: vaultID)
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                    Button {
                        viewModel.showTrash(for: vaultID)
                    } label: {
                        Label("Trash", systemImage: "trash")
                    }
                    Button {
                        viewModel.showSettings(for: vaultID)
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                    Button {
                        Task { await viewModel.lock(vaultID: vaultID) }
                    } label: {
                        Label("Lock", systemImage: "lock")
                    }
                }
            }
            .task(id: vaultID) {
                await viewModel.loadObjects()
            }
        }
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(VaultObjectTypeFilter.allCases) { filter in
                    Button(filter.rawValue) {
                        Task { await viewModel.selectFilter(filter) }
                    }
                    .buttonStyle(.bordered)
                    .tint(viewModel.selectedFilter == filter ? .accentColor : .secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            Spacer()
            ProgressView()
            Spacer()
        case .loaded(let objects):
            List(objects) { object in
                Button {
                    viewModel.selectObject(id: object.id)
                } label: {
                    VaultObjectSummaryRow(object: object)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
        case .empty(let emptyState):
            ContentUnavailableView(
                emptyState.title,
                systemImage: "tray",
                description: Text(emptyState.suggestion)
            )
        case .error(let message):
            ContentUnavailableView {
                Label("Unable to Load Vault", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") {
                    Task { await viewModel.loadObjects() }
                }
            }
        }
    }

    private var searchBinding: Binding<String> {
        Binding(
            get: { viewModel.searchQuery },
            set: { query in Task { await viewModel.search(query: query) } }
        )
    }
}

private struct VaultObjectSummaryRow: View {
    let object: VaultObjectSummaryViewData

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: object.hasThumbnail ? "photo" : iconName)
                .frame(width: 28, height: 28)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(object.title)
                    .lineLimit(2)
                Text(object.updatedAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }

    private var iconName: String {
        switch object.type {
        case .secureNote: "note.text"
        case .identity: "person.text.rectangle"
        case .card: "creditcard"
        case .document: "doc"
        case .photo: "photo"
        }
    }
}
