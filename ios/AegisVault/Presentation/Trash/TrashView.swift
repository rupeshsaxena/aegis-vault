import SecureVaultKit
import SwiftUI

struct TrashView: View {
    let vaultID: VaultID
    @ObservedObject var viewModel: TrashViewModel
    @State private var pendingPermanentDelete: TrashItemViewData?
    @State private var confirmsPurge = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Trash")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            viewModel.close(vaultID: vaultID)
                        } label: {
                            Label("Back to Vault", systemImage: "chevron.left")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) {
                            confirmsPurge = true
                        } label: {
                            Label("Purge Expired", systemImage: "trash.slash")
                        }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    Text("Items are automatically deleted after 30 days")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(.bar)
                }
                .task { await viewModel.loadTrash() }
                .confirmationDialog(
                    "Permanently delete this item?",
                    isPresented: permanentDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete Permanently", role: .destructive) {
                        guard let item = pendingPermanentDelete else { return }
                        Task { await viewModel.permanentlyDelete(id: item.id) }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This action cannot be undone.")
                }
                .confirmationDialog(
                    "Purge expired items?",
                    isPresented: $confirmsPurge,
                    titleVisibility: .visible
                ) {
                    Button("Purge Expired Items", role: .destructive) {
                        Task { await viewModel.purgeTrash() }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Purging is irreversible.")
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView()
        case .loaded(let items):
            List(items) { item in
                TrashItemRow(item: item)
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            Task { await viewModel.restore(id: item.id, vaultID: vaultID) }
                        } label: {
                            Label("Restore", systemImage: "arrow.uturn.backward")
                        }
                        .tint(.green)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            pendingPermanentDelete = item
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
            .listStyle(.plain)
        case .empty:
            ContentUnavailableView(
                "Trash is Empty",
                systemImage: "trash",
                description: Text("Deleted items will appear here.")
            )
        case .failed(let message):
            ContentUnavailableView {
                Label("Unable to Load Trash", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") {
                    Task { await viewModel.loadTrash() }
                }
            }
        }
    }

    private var permanentDeleteConfirmation: Binding<Bool> {
        Binding(
            get: { pendingPermanentDelete != nil },
            set: { if !$0 { pendingPermanentDelete = nil } }
        )
    }
}

private struct TrashItemRow: View {
    let item: TrashItemViewData

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .frame(width: 32, height: 32)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .lineLimit(2)
                Text("Deleted \(item.deletedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let remainingDays = item.remainingDays {
                    Text(remainingDays == 1 ? "1 day remaining" : "\(remainingDays) days remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var iconName: String {
        switch item.type {
        case .secureNote: "note.text"
        case .identity: "person.text.rectangle"
        case .card: "creditcard"
        case .document: "doc"
        case .photo: "photo"
        }
    }
}
