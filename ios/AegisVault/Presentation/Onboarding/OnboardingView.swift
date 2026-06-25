import SecureVaultKit
import SwiftUI

struct OnboardingView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        NavigationStack {
            stepContent
                .navigationTitle("AegisVault")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    if viewModel.state.canGoBack {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Back") { viewModel.back() }
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.state.step {
        case .welcome: welcomeStep
        case .securityPrinciples: securityStep
        case .createVault: createVaultStep
        case .recoveryPackage: recoveryStep
        case .biometricSetup: biometricStep
        case .completion: completionStep
        }
    }

    private var welcomeStep: some View {
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
            Text("A privacy-first, local-first secure vault for your secrets.")
                .font(.body).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal)
            Spacer()
            Button("Get Started") { viewModel.next() }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 32).padding(.bottom, 40)
                .accessibilityIdentifier("getStartedButton")
        }
    }

    private var securityStep: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "shield.fill").font(.system(size: 72)).foregroundStyle(.tint)
            Text("Your Privacy, Guaranteed").font(.title.bold()).multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 12) {
                Label("All data stored locally on your device.", systemImage: "checkmark.circle.fill")
                Label("Nothing sent to the cloud without encryption.", systemImage: "checkmark.circle.fill")
                Label("We never have access to your vault.", systemImage: "checkmark.circle.fill")
            }.padding(.horizontal)
            Spacer()
            Button("Continue") { viewModel.next() }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 32).padding(.bottom, 40)
        }
    }

    private var createVaultStep: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "lock.fill").font(.system(size: 72)).foregroundStyle(.tint)
            Text("Create Your Vault").font(.title.bold())
            Text("Choose a name for your vault.")
                .font(.body).foregroundStyle(.secondary)
            Spacer()
            VStack(spacing: 16) {
                TextField("Vault Name", text: Binding(
                    get: { viewModel.state.vaultName },
                    set: { viewModel.setVaultName($0) }
                ))
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .accessibilityIdentifier("vaultNameField")
                if let error = viewModel.state.errorMessage {
                    Text(error).font(.caption).foregroundStyle(.red)
                        .accessibilityIdentifier("onboardingError")
                }
                Button {
                    Task { await viewModel.createVault() }
                } label: {
                    if viewModel.state.phase == .creating {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Create Vault").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.state.canCreateVault)
                .accessibilityIdentifier("createVaultButton")
            }
            .padding(.horizontal, 32).padding(.bottom, 40)
        }
    }

    private var recoveryStep: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "key.fill").font(.system(size: 72)).foregroundStyle(.orange)
            Text("Recovery Package").font(.title.bold())
            Text("A recovery package lets you regain access if you lose your device.")
                .font(.body).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal)
            Toggle(
                "I understand recovery is my responsibility",
                isOn: Binding(
                    get: { viewModel.state.recoveryWarningAcknowledged },
                    set: { viewModel.setRecoveryWarningAcknowledged($0) }
                )
            ).padding(.horizontal)
            Spacer()
            Button("Continue") { viewModel.next() }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.state.canContinue)
                .padding(.horizontal, 32).padding(.bottom, 40)
        }
    }

    private var biometricStep: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "faceid").font(.system(size: 72)).foregroundStyle(.tint)
            Text("Biometric Unlock").font(.title.bold())
            Text("Set up Face ID or Touch ID for faster access.")
                .font(.body).foregroundStyle(.secondary)
            Spacer()
            VStack(spacing: 12) {
                Button("Set Up Biometrics") { viewModel.next() }
                    .buttonStyle(.borderedProminent).padding(.horizontal, 32)
                Button("Skip") { viewModel.skipBiometricSetup() }
                    .foregroundStyle(.secondary).padding(.horizontal, 32)
            }.padding(.bottom, 40)
        }
    }

    private var completionStep: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 72)).foregroundStyle(.green)
                .accessibilityIdentifier("onboardingSuccessIcon")
            Text("Vault Ready").font(.title.bold())
                .accessibilityIdentifier("onboardingSuccessTitle")
            Text("Your vault is ready. Tap Open Vault to get started.")
                .font(.body).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal)
            Spacer()
            Button("Open Vault") { viewModel.next() }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 32).padding(.bottom, 40)
                .accessibilityIdentifier("openVaultButton")
        }
    }
}
