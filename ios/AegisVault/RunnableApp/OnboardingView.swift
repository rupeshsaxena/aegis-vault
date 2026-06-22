import Observation
import SecureVaultKit
import SwiftUI

// MARK: - View Model

@MainActor
@Observable
final class OnboardingViewModel {
    var vaultName: String = ""
    var errorMessage: String?
    var completedVaultID: VaultID?

    private(set) var isCreating: Bool = false
    private(set) var createdVaultID: VaultID?

    var canCreateVault: Bool {
        !isCreating && !vaultName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @ObservationIgnored private let createVaultUseCase: any CreateVaultUsing
    @ObservationIgnored private let deviceID: DeviceID

    init(createVaultUseCase: any CreateVaultUsing, deviceID: DeviceID = DeviceID()) {
        self.createVaultUseCase = createVaultUseCase
        self.deviceID = deviceID
    }

    func createVault() async {
        let trimmed = vaultName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isCreating = true
        errorMessage = nil

        do {
            let vaultID = try await createVaultUseCase.execute(
                name: trimmed,
                deviceID: deviceID,
                unlockMethod: .passphrase
            )
            createdVaultID = vaultID
        } catch {
            errorMessage = "Failed to create vault: \(error.localizedDescription)"
        }

        isCreating = false
    }

    func completeOnboarding() {
        completedVaultID = createdVaultID
    }
}

// MARK: - View

struct OnboardingView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.createdVaultID != nil {
                    completionStep
                } else {
                    createVaultStep
                }
            }
            .navigationTitle("AegisVault")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var createVaultStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.shield")
                .font(.system(size: 72))
                .foregroundStyle(.tint)
                .accessibilityIdentifier("onboardingIcon")

            Text("Welcome to AegisVault")
                .font(.title.bold())
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("onboardingTitle")

            Text("Create a vault to securely store your secrets.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            VStack(spacing: 16) {
                TextField("Vault Name", text: $viewModel.vaultName)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("vaultNameField")

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("onboardingError")
                }

                Button {
                    Task { await viewModel.createVault() }
                } label: {
                    if viewModel.isCreating {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Create Vault")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canCreateVault)
                .accessibilityIdentifier("createVaultButton")
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
    }

    private var completionStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
                .accessibilityIdentifier("onboardingSuccessIcon")

            Text("Vault Created")
                .font(.title.bold())
                .accessibilityIdentifier("onboardingSuccessTitle")

            Text("Your vault is ready. Let's get started.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            Button("Open Vault") {
                viewModel.completeOnboarding()
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
            .accessibilityIdentifier("openVaultButton")
        }
    }
}
