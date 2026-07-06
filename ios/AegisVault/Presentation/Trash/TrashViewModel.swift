import Combine
import SecureVaultKit

@MainActor
final class TrashViewModel: ObservableObject {
    @Published private(set) var state: TrashState = .idle
    @Published private(set) var route: AppRoute?

    private let trashService: any TrashApplicationServicing

    init(trashService: any TrashApplicationServicing) {
        self.trashService = trashService
    }

    func loadTrash() async {
        state = .loading
        do {
            let summaries = try await trashService.listTrash()
            present(summaries.map { TrashItemViewData(summary: $0) })
        } catch {
            state = .failed(Self.message(for: error, fallback: "Unable to load Trash."))
        }
    }

    func restore(id: VaultObjectID, vaultID: VaultID? = nil) async {
        do {
            try await trashService.restore(id: id)
            removeFromState(id: id)
            if let vaultID {
                route = .vaultHome(vaultID)
            }
        } catch {
            state = .failed(Self.message(for: error, fallback: "Unable to restore item."))
        }
    }

    func permanentlyDelete(id: VaultObjectID) async {
        do {
            try await trashService.permanentlyDelete(id: id)
            removeFromState(id: id)
        } catch {
            state = .failed(Self.message(for: error, fallback: "Unable to permanently delete item."))
        }
    }

    func purgeTrash() async {
        do {
            try await trashService.purgeExpired()
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
