import SwiftUI

struct OnboardingView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                stepProgress
                Group {
                    switch viewModel.state.step {
                    case .welcome:
                        WelcomeOnboardingScreen()
                    case .securityPrinciples:
                        SecurityPrinciplesOnboardingScreen()
                    case .createVault:
                        CreateVaultOnboardingScreen(viewModel: viewModel)
                    case .recoveryPackage:
                        RecoveryPackageOnboardingScreen(viewModel: viewModel)
                    case .biometricSetup:
                        BiometricSetupOnboardingScreen()
                    case .completion:
                        CompletionOnboardingScreen()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if viewModel.state.canGoBack {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Back", systemImage: "chevron.left") {
                            viewModel.back()
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomAction
                    .padding()
                    .background(.bar)
            }
        }
    }

    private var stepProgress: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                Capsule()
                    .fill(step.rawValue <= viewModel.state.step.rawValue ? Color.accentColor : Color.secondary.opacity(0.2))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var bottomAction: some View {
        switch viewModel.state.step {
        case .welcome, .securityPrinciples:
            Button("Continue", systemImage: "arrow.right") {
                viewModel.next()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        case .createVault:
            Button {
                Task { await viewModel.createVault() }
            } label: {
                if viewModel.state.phase == .creating {
                    ProgressView()
                } else {
                    Label("Create Vault", systemImage: "lock.shield")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.state.canCreateVault)
            .frame(maxWidth: .infinity)
        case .recoveryPackage:
            Button("Continue", systemImage: "arrow.right") {
                viewModel.next()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.state.canContinue)
            .frame(maxWidth: .infinity)
        case .biometricSetup:
            Button("Skip for Now", systemImage: "forward") {
                viewModel.skipBiometricSetup()
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
        case .completion:
            Button("Open Vault", systemImage: "lock.open") {
                viewModel.next()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.state.canContinue)
            .frame(maxWidth: .infinity)
        }
    }

    private var navigationTitle: String {
        switch viewModel.state.step {
        case .welcome: "Welcome"
        case .securityPrinciples: "Security"
        case .createVault: "Create Vault"
        case .recoveryPackage: "Recovery"
        case .biometricSetup: "Quick Unlock"
        case .completion: "Ready"
        }
    }
}

private struct WelcomeOnboardingScreen: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("AegisVault")
                .font(.largeTitle.bold())
            Text("A private place for your most important information.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(32)
    }
}

private struct SecurityPrinciplesOnboardingScreen: View {
    var body: some View {
        List {
            principle("Local First", detail: "Your device is the primary source of truth.", icon: "iphone")
            principle("Encrypted", detail: "Vault content is encrypted before persistence.", icon: "lock")
            principle("Zero Knowledge", detail: "AegisVault services cannot read your vault.", icon: "eye.slash")
        }
        .listStyle(.plain)
    }

    private func principle(_ title: String, detail: String, icon: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: icon).foregroundStyle(.tint)
        }
        .padding(.vertical, 8)
    }
}

private struct CreateVaultOnboardingScreen: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        Form {
            TextField(
                "Vault name",
                text: Binding(
                    get: { viewModel.state.vaultName },
                    set: viewModel.setVaultName
                )
            )
            .textInputAutocapitalization(.words)
            if let errorMessage = viewModel.state.errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
        }
    }
}

private struct RecoveryPackageOnboardingScreen: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        Form {
            Section {
                Label("Recovery is required", systemImage: "exclamationmark.shield")
                    .font(.headline)
                Text("Keep your recovery package and recovery secret safe. Support cannot recover your vault without them.")
                    .foregroundStyle(.secondary)
            }
            Section {
                Toggle(
                    "I understand that recovery material is required",
                    isOn: Binding(
                        get: { viewModel.state.recoveryWarningAcknowledged },
                        set: viewModel.setRecoveryWarningAcknowledged
                    )
                )
            }
        }
    }
}

private struct BiometricSetupOnboardingScreen: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "faceid")
                .font(.system(size: 56))
            Text("Quick Unlock")
                .font(.title.bold())
            Text("Biometric and passkey setup will be available here. This optional step can be completed later in Settings.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(32)
    }
}

private struct CompletionOnboardingScreen: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("Vault Created")
                .font(.title.bold())
            Text("Your vault is ready.")
                .foregroundStyle(.secondary)
        }
        .padding(32)
    }
}
