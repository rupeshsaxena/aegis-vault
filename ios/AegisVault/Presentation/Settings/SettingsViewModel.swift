import Combine
import SecureVaultKit

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var state: SettingsState = .idle
    @Published private(set) var route: AppRoute?

    private let getSecurityStatusUseCase: any GetSecurityStatusUsing

    init(getSecurityStatusUseCase: any GetSecurityStatusUsing) {
        self.getSecurityStatusUseCase = getSecurityStatusUseCase
    }

    func loadSettings() async {
        state = .loading
        do {
            state = .loaded(
                SettingsSummaryViewData(status: try await getSecurityStatusUseCase.execute())
            )
        } catch {
            state = .failed("Unable to load settings.")
        }
    }

    func showSecurityCenter(vaultID: VaultID) {
        route = .securityCenter(vaultID)
    }

    func showRecovery(vaultID: VaultID) {
        route = .securityCenter(vaultID)
    }

    func showDevices(vaultID: VaultID) {
        route = .securityCenter(vaultID)
    }

    func showTrash(vaultID: VaultID) {
        route = .trash(vaultID)
    }

    func close(vaultID: VaultID) {
        route = .vaultHome(vaultID)
    }

    func clearRoute() {
        route = nil
    }
}
