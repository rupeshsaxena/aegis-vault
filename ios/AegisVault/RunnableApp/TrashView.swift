import Observation
import SecureVaultKit
import SwiftUI

// MARK: - View Model

@MainActor
@Observable
final class TrashViewModel {
    private(set) var objects: [VaultObjectSummary] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    var isEmpty: Bool { !isLoading && objects.isEmpty && errorMessage == nil }

    @ObservationIgnored private let listObjectsUseCase: any ListVaultObjectsUsing
    @ObservationIgnored private let restoreFromTrashUseCase: any RestoreFromTrashUsing

    init(
        listObjectsUseCase: any ListVaultObjectsUsing,
        restoreFromTrashUseCase: any RestoreFromTrashUsing
    ) {
        self.listObjectsUseCase = listObjectsUseCase
        self.restoreFromTrashUseCase = restoreFromTrashUseCase
    }

    func loadObjects() async {
        isLoading = true
        errorMessage = nil
        do {
            let all = try await listObjectsUseCase.execute(filter: VaultObjectFilter(includeDeleted: true))
            objects = all.filter { $0.isDeleted }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func restore(id: VaultObjectID) async {
        do {
            try await restoreFromTrashUseCase.execute(id: id)
            objects.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - View

struct TrashView: View {
    let onRestored: () -> Void
    @State private var viewModel: TrashViewModel

    @MainActor init(flow: VaultHomeFlowUseCases, onRestored: @escaping () -> Void) {
        self.onRestored = onRestored
        _viewModel = State(initialValue: TrashViewModel(
            listObjectsUseCase: flow.listObjects,
            restoreFromTrashUseCase: flow.restoreFromTrash
        ))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else if let error = viewModel.errorMessage {
                ContentUnavailableView(
                    "Unable to Load Trash",
                    systemImage: "exclamationmark.circle",
                    description: Text(error)
                )
            } else if viewModel.isEmpty {
                ContentUnavailableView(
                    "Trash Is Empty",
                    systemImage: "trash",
                    description: Text("Deleted items appear here for 30 days.")
                )
                .accessibilityIdentifier("trashEmptyState")
            } else {
                trashList
            }
        }
        .navigationTitle("Trash")
        .navigationBarTitleDisplayMode(.large)
        .task { await viewModel.loadObjects() }
        .refreshable { await viewModel.loadObjects() }
    }

    private var trashList: some View {
        List(viewModel.objects, id: \.id) { object in
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(object.title)
                        .font(.body)
                    if let deletedAt = object.deletedAt {
                        Text("Deleted \(deletedAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button("Restore") {
                    Task {
                        await viewModel.restore(id: object.id)
                        onRestored()
                    }
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("restoreButton")
            }
        }
        .accessibilityIdentifier("trashObjectList")
    }
}
