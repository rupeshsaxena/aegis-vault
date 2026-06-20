import Combine
import Foundation
import SecureVaultKit

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published private(set) var state = OnboardingState()
    private let createVaultUseCase: any CreateVaultUsing
    private let deviceID: DeviceID

    init(
        createVaultUseCase: any CreateVaultUsing,
        deviceID: DeviceID = DeviceID()
    ) {
        self.createVaultUseCase = createVaultUseCase
        self.deviceID = deviceID
    }

    func setVaultName(_ name: String) {
        state.vaultName = name
        state.errorMessage = nil
    }

    func createVault() async {
        guard state.canCreateVault else { return }
        state.phase = .creating
        state.errorMessage = nil
        do {
            state.createdVaultID = try await createVaultUseCase.execute(
                name: state.vaultName.trimmingCharacters(in: .whitespacesAndNewlines),
                deviceID: deviceID,
                unlockMethod: .passphrase
            )
            state.phase = .created
        } catch {
            state.phase = .failed
            state.errorMessage = "Unable to create the vault."
        }
    }
}
