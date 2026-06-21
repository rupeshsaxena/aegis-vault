import SwiftUI

struct RootView: View {
    @StateObject private var rootViewModel: RootViewModel
    @StateObject private var onboardingViewModel: OnboardingViewModel
    @StateObject private var unlockViewModel: UnlockViewModel
    @StateObject private var vaultHomeViewModel: VaultHomeViewModel
    @StateObject private var objectDetailViewModel: ObjectDetailViewModel
    @StateObject private var identityEditorViewModel: IdentityEditorViewModel
    @StateObject private var cardEditorViewModel: CardEditorViewModel

    @MainActor
    init(container: AppContainer) {
        _rootViewModel = StateObject(wrappedValue: container.makeRootViewModel())
        _onboardingViewModel = StateObject(wrappedValue: container.makeOnboardingViewModel())
        _unlockViewModel = StateObject(wrappedValue: container.makeUnlockViewModel())
        _vaultHomeViewModel = StateObject(wrappedValue: container.makeVaultHomeViewModel())
        _objectDetailViewModel = StateObject(wrappedValue: container.makeObjectDetailViewModel())
        _identityEditorViewModel = StateObject(wrappedValue: container.makeIdentityEditorViewModel())
        _cardEditorViewModel = StateObject(wrappedValue: container.makeCardEditorViewModel())
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
            case .identityEditor(let mode):
                IdentityEditorView(mode: mode, viewModel: identityEditorViewModel)
            case .cardEditor(let mode):
                CardEditorView(mode: mode, viewModel: cardEditorViewModel)
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
        .onChange(of: identityEditorViewModel.route) { _, route in
            guard let route else { return }
            rootViewModel.navigate(to: route)
            identityEditorViewModel.clearRoute()
        }
        .onChange(of: cardEditorViewModel.route) { _, route in
            guard let route else { return }
            rootViewModel.navigate(to: route)
            cardEditorViewModel.clearRoute()
        }
    }

    private func placeholder(title: String, systemImage: String) -> some View {
        ContentUnavailableView(title, systemImage: systemImage)
    }
}
