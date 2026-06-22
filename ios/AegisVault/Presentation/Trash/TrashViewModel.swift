import Combine
import SecureVaultKit

@MainActor
final class TrashViewModel: ObservableObject {
    @Published private(set) var state: TrashState = .idle
    @Published private(set) var route: AppRoute?

    private let listTrashObjectsUseCase: any ListTrashObjectsUsing
    private let restoreFromTrashUseCase: any RestoreFromTrashUsing
    private let purgeTrashUseCase: any PurgeTrashUsing
    private let permanentlyDeleteObjectUseCase: any PermanentlyDeleteObjectUsing

    init(
        listTrashObjectsUseCase: any ListTrashObjectsUsing,
        restoreFromTrashUseCase: any RestoreFromTrashUsing,
        purgeTrashUseCase: any PurgeTrashUsing,
        permanentlyDeleteObjectUseCase: any PermanentlyDeleteObjectUsing
    ) {
        self.listTrashObjectsUseCase = listTrashObjectsUseCase
        self.restoreFromTrashUseCase = restoreFromTrashUseCase
        self.purgeTrashUseCase = purgeTrashUseCase
        self.permanentlyDeleteObjectUseCase = permanentlyDeleteObjectUseCase
    }

    func loadTrash() async {
        state = .loading
        do {
            let summaries = try await listTrashObjectsUseCase.execute()
            present(summaries.map { TrashItemViewData(summary: $0) })
        } catch {
            state = .failed(Self.message(for: error, fallback: "Unable to load Trash."))
        }
    }

    func restore(id: VaultObjectID) async {
        do {
            try await restoreFromTrashUseCase.execute(id: id)
            removeFromState(id: id)
        } catch {
            state = .failed(Self.message(for: error, fallback: "Unable to restore item."))
        }
    }

    func permanentlyDelete(id: VaultObjectID) async {
        do {
            try await permanentlyDeleteObjectUseCase.execute(id: id)
            removeFromState(id: id)
        } catch {
            state = .failed(Self.message(for: error, fallback: "Unable to permanently delete item."))
        }
    }

    func purgeTrash() async {
        do {
            try await purgeTrashUseCase.execute()
            await loadTrash()
        } catch {
            state = .failed(Self.message(for: error, fallback: "Unable to purge Trash."))
        }
    }

    func close(vaultID: VaultID) {
        route = .vaultHome(vaultID)
    }

    func clearRoute() {
        route = nil
    }

    private func removeFromState(id: VaultObjectID) {
        guard case .loaded(let items) = state else {
            state = .empty
            return
        }
        present(items.filter { $0.id != id })
    }

    private func present(_ items: [TrashItemViewData]) {
        state = items.isEmpty ? .empty : .loaded(items)
    }

    private static func message(for error: Error, fallback: String) -> String {
        if case VaultError.locked = error {
            return "Your vault is locked."
        }
        return fallback
    }
}
