import Combine
import Foundation
import SecureVaultKit

@MainActor
final class TrashViewModel: ObservableObject {
    @Published private(set) var state: TrashState = .idle
    @Published private(set) var route: AppRoute?

    private let trashService: any TrashApplicationServicing
    private let errorMapper: any ErrorMapper
    private var loadTask: Task<Void, Never>?
    private var loadRequestID = UUID()

    init(
        trashService: any TrashApplicationServicing,
        errorMapper: any ErrorMapper = DefaultErrorMapper()
    ) {
        self.trashService = trashService
        self.errorMapper = errorMapper
    }

    deinit {
        loadTask?.cancel()
    }

    func loadTrash() async {
        loadTask?.cancel()
        let requestID = beginLoadRequest()
        state = .loading
        let task = Task { [trashService] in
            do {
                let summaries = try await trashService.listTrash()
                try Task.checkCancellation()
                let items = summaries.map { TrashItemViewData(summary: $0) }
                await MainActor.run {
                    guard self.loadRequestID == requestID else { return }
                    self.present(items)
                }
            } catch is CancellationError {
            } catch {
                await MainActor.run {
                    guard self.loadRequestID == requestID else { return }
                    self.state = .failed(self.message(for: error, fallback: "Unable to load Trash."))
                }
            }
        }
        loadTask = task
        await task.value
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

    private func beginLoadRequest() -> UUID {
        let requestID = UUID()
        loadRequestID = requestID
        return requestID
    }
}
