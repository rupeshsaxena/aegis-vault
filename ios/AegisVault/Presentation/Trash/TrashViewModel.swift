import Combine
import SecureVaultKit

@MainActor
final class TrashViewModel: ObservableObject {
    @Published private(set) var state: TrashState = .idle
    @Published private(set) var route: AppRoute?

    private let trashService: any TrashApplicationServicing
    private let errorMapper: any ErrorMapper

    init(
        trashService: any TrashApplicationServicing,
        errorMapper: any ErrorMapper = DefaultErrorMapper()
    ) {
        self.trashService = trashService
        self.errorMapper = errorMapper
    }

    func loadTrash() async {
        state = .loading
        do {
            let summaries = try await trashService.listTrash()
            present(summaries.map { TrashItemViewData(summary: $0) })
        } catch {
            state = .failed(message(for: error, fallback: "Unable to load Trash."))
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
            state = .failed(message(for: error, fallback: "Unable to restore item."))
        }
    }

    func permanentlyDelete(id: VaultObjectID) async {
        do {
            try await trashService.permanentlyDelete(id: id)
            removeFromState(id: id)
        } catch {
            state = .failed(message(for: error, fallback: "Unable to permanently delete item."))
        }
    }

    func purgeTrash() async {
        do {
            try await trashService.purgeExpired()
            await loadTrash()
        } catch {
            state = .failed(message(for: error, fallback: "Unable to purge Trash."))
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

    private func message(for error: Error, fallback: String) -> String {
        errorMapper.userMessage(
            for: error,
            fallback: UserMessage(title: "Trash Error", message: fallback)
        ).message
    }
}
