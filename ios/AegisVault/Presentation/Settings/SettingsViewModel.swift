import Combine
import SecureVaultKit

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var state: SettingsState = .idle
    @Published private(set) var route: AppRoute?

    private let getSecurityStatusUseCase: any GetSecurityStatusUsing
    private let errorMapper: any ErrorMapper

    init(
        getSecurityStatusUseCase: any GetSecurityStatusUsing,
        errorMapper: any ErrorMapper = DefaultErrorMapper()
    ) {
        self.getSecurityStatusUseCase = getSecurityStatusUseCase
        self.errorMapper = errorMapper
    }

    func loadSettings() async {
        state = .loading
        do {
            state = .loaded(
                SettingsSummaryViewData(status: try await getSecurityStatusUseCase.execute())
            )
        } catch {
            state = .failed(errorMapper.userMessage(
                for: error,
                fallback: UserMessage(title: "Unable to Load Settings", message: "Unable to load settings.")
            ).message)
        }
    }

    func showSecurityCenter(vaultID: VaultID) {
        route = .securityCenter(vaultID)
    }

    func showRecovery(vaultID: VaultID) {
        route = .recoverySettings(vaultID)
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
