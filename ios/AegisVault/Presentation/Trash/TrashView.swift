import SecureVaultKit
import SwiftUI

struct TrashView: View {
    let vaultID: VaultID
    @ObservedObject var viewModel: TrashViewModel

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Trash")
                .navigationBarTitleDisplayMode(.large)
                .toolbar { toolbarItems }
                .task { await viewModel.loadTrash() }
                .refreshable { await viewModel.loadTrash() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView()
        case .empty:
            ContentUnavailableView(
                "Trash Is Empty",
                systemImage: "trash",
                description: Text("Deleted items appear here.")
            )
            .accessibilityIdentifier("trashEmptyState")
        case .loaded(let items):
            trashList(items)
        case .failed(let message):
            ContentUnavailableView(
                "Unable to Load Trash",
                systemImage: "exclamationmark.circle",
                description: Text(message)
            )
        }
    }

    private func trashList(_ items: [TrashItemViewData]) -> some View {
        List(items) { item in
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title).font(.body)
                    Text("Deleted \(item.deletedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption).foregroundStyle(.secondary)
                    if let days = item.remainingDays {
                        Text("\(days) days until permanent deletion")
                            .font(.caption2).foregroundStyle(.orange)
                    }
                }
                Spacer()
                Button("Restore") {
                    Task { await viewModel.restore(id: item.id, vaultID: vaultID) }
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("restoreButton")
            }
        }
        .accessibilityIdentifier("trashObjectList")
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Empty Trash", role: .destructive) {
                Task { await viewModel.purgeTrash() }
            }
            .disabled({
                if case .loaded(let items) = viewModel.state { return items.isEmpty }
                return true
            }())
        }
    }
}
