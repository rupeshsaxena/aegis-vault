import Combine
import Foundation
import SecureVaultKit

@MainActor
final class VaultHomeViewModel: ObservableObject {
    @Published private(set) var state = VaultHomeState()
    private let listVaultObjectsUseCase: any ListVaultObjectsUsing
    private let searchVaultUseCase: any SearchVaultUsing
    private let lockVaultUseCase: any LockVaultUsing

    init(
        listVaultObjectsUseCase: any ListVaultObjectsUsing,
        searchVaultUseCase: any SearchVaultUsing,
        lockVaultUseCase: any LockVaultUsing
    ) {
        self.listVaultObjectsUseCase = listVaultObjectsUseCase
        self.searchVaultUseCase = searchVaultUseCase
        self.lockVaultUseCase = lockVaultUseCase
    }

    func loadObjects() async {
        state.phase = .loading
        state.errorMessage = nil
        do {
            state.objects = try await listVaultObjectsUseCase.execute(filter: VaultObjectFilter())
            state.phase = .loaded
        } catch {
            state.phase = .failed
            state.errorMessage = "Unable to load vault items."
        }
    }

    func search(query: String) async {
        state.searchQuery = query
        state.errorMessage = nil
        do {
            state.objects = try await searchVaultUseCase.execute(query: query)
            state.phase = .loaded
        } catch {
            state.phase = .failed
            state.errorMessage = "Unable to search the vault."
        }
    }

    func lock(vaultID: VaultID) async {
        await lockVaultUseCase.execute(vaultID: vaultID)
        state.objects = []
        state.searchQuery = ""
        state.lockedVaultID = vaultID
    }
}
