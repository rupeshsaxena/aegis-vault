import SwiftUI

struct RootView: View {
    @State private var viewModel: RootViewModel

    @MainActor
    init(container: AppContainer) {
        _viewModel = State(initialValue: container.makeRootViewModel())
    }

    var body: some View {
        Group {
            switch viewModel.route {
            case .onboarding:
                OnboardingView()
            case .unlock:
                UnlockView()
            case .vaultHome:
                VaultHomeView()
            case nil:
                ProgressView()
            }
        }
        .task {
            await viewModel.determineInitialRoute()
        }
    }
}

