import SwiftUI

struct RootView: View {
    @StateObject private var rootViewModel: RootViewModel
    @StateObject private var onboardingViewModel: OnboardingViewModel
    @StateObject private var unlockViewModel: UnlockViewModel
    @StateObject private var vaultHomeViewModel: VaultHomeViewModel

    @MainActor
    init(container: AppContainer) {
        _rootViewModel = StateObject(wrappedValue: container.makeRootViewModel())
        _onboardingViewModel = StateObject(wrappedValue: container.makeOnboardingViewModel())
        _unlockViewModel = StateObject(wrappedValue: container.makeUnlockViewModel())
        _vaultHomeViewModel = StateObject(wrappedValue: container.makeVaultHomeViewModel())
    }

    var body: some View {
        Group {
            switch rootViewModel.route {
            case .onboarding:
                OnboardingView(viewModel: onboardingViewModel)
            case .unlock(let vaultID):
                UnlockView(vaultID: vaultID, viewModel: unlockViewModel)
            case .vaultHome(let vaultID):
                VaultHomeView(
                    vaultID: vaultID,
                    viewModel: vaultHomeViewModel,
                    navigate: rootViewModel.navigate
                )
            case .objectDetail:
                placeholder(title: "Object Detail", systemImage: "doc.text")
            case .importDocument:
                placeholder(title: "Import Document", systemImage: "square.and.arrow.down")
            case .trash:
                placeholder(title: "Trash", systemImage: "trash")
            case .settings:
                placeholder(title: "Settings", systemImage: "gearshape")
            case nil:
                if let errorMessage = rootViewModel.errorMessage {
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
            await rootViewModel.resolveInitialRoute()
        }
        .onChange(of: onboardingViewModel.state.completedVaultID) { _, vaultID in
            guard let vaultID else { return }
            rootViewModel.navigate(to: .vaultHome(vaultID))
        }
        .onChange(of: unlockViewModel.state.unlockedVaultID) { _, vaultID in
            guard let vaultID else { return }
            rootViewModel.handleUnlockSuccess(vaultID: vaultID)
        }
        .onChange(of: vaultHomeViewModel.state.lockedVaultID) { _, vaultID in
            guard let vaultID else { return }
            rootViewModel.handleLock(vaultID: vaultID)
        }
    }

    private func placeholder(title: String, systemImage: String) -> some View {
        ContentUnavailableView(title, systemImage: systemImage)
    }
}
