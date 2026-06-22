import SwiftUI

struct RootView: View {
    @State private var viewModel: RootViewModel
    @State private var onboardingViewModel: OnboardingViewModel
    @State private var vaultHomeViewModel: VaultHomeViewModel

    @MainActor
    init(container: AppContainer) {
        _viewModel = State(initialValue: container.makeRootViewModel())
        _onboardingViewModel = State(initialValue: container.makeOnboardingViewModel())
        _vaultHomeViewModel = State(initialValue: container.makeVaultHomeViewModel())
    }

    var body: some View {
        Group {
            switch viewModel.route {
            case .onboarding:
                OnboardingView(viewModel: onboardingViewModel)
            case .unlock(let vaultID):
                UnlockView(vaultID: vaultID)
            case .vaultHome(let vaultID):
                VaultHomeView(vaultID: vaultID, viewModel: vaultHomeViewModel)
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
