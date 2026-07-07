import Combine
import SecureVaultKit

@MainActor
final class RecoverySettingsViewModel: ObservableObject {
    @Published private(set) var state: RecoverySettingsState = .idle
    @Published private(set) var hasAcknowledgedRisk = false
    @Published private(set) var route: AppRoute?

    private let getRecoveryStatusUseCase: any GetRecoveryStatusUsing
    private let exportRecoveryPackageUseCase: any ExportRecoveryPackageUsing
    private let errorMapper: any ErrorMapper

    init(
        getRecoveryStatusUseCase: any GetRecoveryStatusUsing,
        exportRecoveryPackageUseCase: any ExportRecoveryPackageUsing,
        errorMapper: any ErrorMapper = DefaultErrorMapper()
    ) {
        self.getRecoveryStatusUseCase = getRecoveryStatusUseCase
        self.exportRecoveryPackageUseCase = exportRecoveryPackageUseCase
        self.errorMapper = errorMapper
    }

    func loadStatus() async {
        state = .loading
        do {
            state = .loaded(
                RecoveryStatusViewData(status: try await getRecoveryStatusUseCase.execute())
            )
        } catch {
            state = .failed(message(for: error, fallback: "Unable to load recovery status."))
        }
    }

    func setAcknowledgedRisk(_ acknowledged: Bool) {
        hasAcknowledgedRisk = acknowledged
    }

    func exportPackage() async {
        guard hasAcknowledgedRisk else {
            state = .failed("Acknowledge the recovery responsibility before exporting.")
            return
        }
        state = .exporting
        do {
            let export = try await exportRecoveryPackageUseCase.execute(acknowledgingRisk: true)
            state = .exported(RecoveryExportViewData(export: export))
        } catch {
            state = .failed(message(for: error, fallback: "Unable to export recovery package."))
        }
    }

    func close(vaultID: VaultID) {
        route = .settings(vaultID)
    }

    func clearRoute() {
        route = nil
    }

    private func message(for error: Error, fallback: String) -> String {
        errorMapper.userMessage(
            for: error,
            fallback: UserMessage(title: "Recovery Error", message: fallback)
        ).message
    }
}
