import SwiftUI

struct RootView: View {
    @StateObject private var rootViewModel: RootViewModel
    @StateObject private var onboardingViewModel: OnboardingViewModel
    @StateObject private var unlockViewModel: UnlockViewModel
    @StateObject private var vaultHomeViewModel: VaultHomeViewModel
    @StateObject private var objectDetailViewModel: ObjectDetailViewModel

    @MainActor
    init(container: AppContainer) {
        _rootViewModel = StateObject(wrappedValue: container.makeRootViewModel())
        _onboardingViewModel = StateObject(wrappedValue: container.makeOnboardingViewModel())
        _unlockViewModel = StateObject(wrappedValue: container.makeUnlockViewModel())
        _vaultHomeViewModel = StateObject(wrappedValue: container.makeVaultHomeViewModel())
        _objectDetailViewModel = StateObject(wrappedValue: container.makeObjectDetailViewModel())
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
                    viewModel: vaultHomeViewModel
                )
            case .objectDetail(let objectID):
                ObjectDetailView(objectID: objectID, viewModel: objectDetailViewModel)
            case .objectEditor:
                placeholder(title: "Object Editor", systemImage: "pencil")
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
        .onChange(of: vaultHomeViewModel.lockedVaultID) { _, vaultID in
            guard let vaultID else { return }
            rootViewModel.handleLock(vaultID: vaultID)
        }
        .onChange(of: vaultHomeViewModel.route) { _, route in
            guard let route else { return }
            rootViewModel.navigate(to: route)
            vaultHomeViewModel.clearRoute()
        }
        .onChange(of: objectDetailViewModel.route) { _, route in
            guard let route else { return }
            rootViewModel.navigate(to: route)
            objectDetailViewModel.clearRoute()
        }
    }

    private func placeholder(title: String, systemImage: String) -> some View {
        ContentUnavailableView(title, systemImage: systemImage)
    }
}
