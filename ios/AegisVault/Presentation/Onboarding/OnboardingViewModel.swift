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
        if state.phase == .failed {
            state.phase = .idle
        }
    }

    func next() {
        guard state.canContinue else { return }
        if state.step == .completion {
            state.completedVaultID = state.createdVaultID
            return
        }
        guard let nextStep = state.step.next else { return }
        state.step = nextStep
        state.errorMessage = nil
    }

    func back() {
        guard state.canGoBack, let previousStep = state.step.previous else { return }
        state.step = previousStep
        state.errorMessage = nil
    }

    func setRecoveryWarningAcknowledged(_ acknowledged: Bool) {
        state.recoveryWarningAcknowledged = acknowledged
    }

    func skipBiometricSetup() {
        guard state.step == .biometricSetup else { return }
        state.biometricSetupSkipped = true
        state.step = .completion
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
            state.step = .recoveryPackage
        } catch {
            state.phase = .failed
            state.errorMessage = "Unable to create the vault."
        }
    }
}
