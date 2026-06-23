import SwiftUI

struct RootView: View {
    @State private var viewModel: RootViewModel
    @State private var onboardingViewModel: OnboardingViewModel
    let vaultHomeFlow: VaultHomeFlowUseCases

    @MainActor
    init(container: AppContainer) {
        _viewModel = State(initialValue: container.makeRootViewModel())
        _onboardingViewModel = State(initialValue: container.makeOnboardingViewModel())
        vaultHomeFlow = container.makeVaultHomeFlow()
    }

    var body: some View {
        Group {
            switch viewModel.route {
            case .onboarding:
                OnboardingView(viewModel: onboardingViewModel)
            case .unlock(let vaultID):
                UnlockView(vaultID: vaultID)
            case .vaultHome(let vaultID):
                VaultHomeView(vaultID: vaultID, flow: vaultHomeFlow)
            case nil:
                if let errorMessage = viewModel.errorMessage {
                    ContentUnavailableView(
                        "Unable to Open AegisVault",
                        systemImage: "exclamationmark.lock",
                        description: Text(errorMessage)
                    )
                } else {
                    ProgressView()
                }
            }
        }
        .task {
            await viewModel.determineInitialRoute()
        }
        .onChange(of: onboardingViewModel.completedVaultID) { _, vaultID in
            guard let vaultID else { return }
            viewModel.navigate(to: .vaultHome(vaultID))
        }
    }
}
