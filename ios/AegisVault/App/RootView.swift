import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var rootViewModel: RootViewModel
    @StateObject private var onboardingViewModel: OnboardingViewModel
    @StateObject private var unlockViewModel: UnlockViewModel
    @StateObject private var vaultHomeViewModel: VaultHomeViewModel
    @StateObject private var objectDetailViewModel: ObjectDetailViewModel
    @StateObject private var secureNoteEditorViewModel: SecureNoteEditorViewModel
    @StateObject private var identityEditorViewModel: IdentityEditorViewModel
    @StateObject private var cardEditorViewModel: CardEditorViewModel
    @StateObject private var documentImportViewModel: DocumentImportViewModel
    @StateObject private var trashViewModel: TrashViewModel
    @StateObject private var settingsViewModel: SettingsViewModel
    @StateObject private var securityCenterViewModel: SecurityCenterViewModel
    @StateObject private var recoverySettingsViewModel: RecoverySettingsViewModel
    @StateObject private var privacyShieldController: PrivacyShieldController
    @StateObject private var screenCaptureObserver: ScreenCaptureObserver
    private let lifecycleCoordinator: AppLifecycleCoordinator

    @MainActor
    init(container: AppContainer) {
        _rootViewModel = StateObject(wrappedValue: container.makeRootViewModel())
        _onboardingViewModel = StateObject(wrappedValue: container.makeOnboardingViewModel())
        _unlockViewModel = StateObject(wrappedValue: container.makeUnlockViewModel())
        _vaultHomeViewModel = StateObject(wrappedValue: container.makeVaultHomeViewModel())
        let objectDetailViewModel = container.makeObjectDetailViewModel()
        _objectDetailViewModel = StateObject(wrappedValue: objectDetailViewModel)
        _secureNoteEditorViewModel = StateObject(wrappedValue: container.makeSecureNoteEditorViewModel())
        _identityEditorViewModel = StateObject(wrappedValue: container.makeIdentityEditorViewModel())
        _cardEditorViewModel = StateObject(wrappedValue: container.makeCardEditorViewModel())
        _documentImportViewModel = StateObject(wrappedValue: container.makeDocumentImportViewModel())
        _trashViewModel = StateObject(wrappedValue: container.makeTrashViewModel())
        _settingsViewModel = StateObject(wrappedValue: container.makeSettingsViewModel())
        _securityCenterViewModel = StateObject(wrappedValue: container.makeSecurityCenterViewModel())
        _recoverySettingsViewModel = StateObject(wrappedValue: container.makeRecoverySettingsViewModel())
        let privacyShieldController = container.makePrivacyShieldController()
        _privacyShieldController = StateObject(wrappedValue: privacyShieldController)
        _screenCaptureObserver = StateObject(wrappedValue: ScreenCaptureObserver())
        lifecycleCoordinator = container.makeAppLifecycleCoordinator(
            sensitiveStateResetHandler: {
                objectDetailViewModel.clearSensitivePresentationState()
            }
        )
    }

    var body: some View {
        routedContent
        .privacyShielded(by: privacyShieldController)
        .task {
            await rootViewModel.resolveInitialRoute()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            Task { await handleScenePhaseChange(from: oldPhase, to: newPhase) }
        }
        .onChange(of: onboardingViewModel.state.completedVaultID) { _, vaultID in
            guard let vaultID else { return }
            rootViewModel.handleOnboardingFinished(vaultID: vaultID)
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
        .onChange(of: secureNoteEditorViewModel.route) { _, route in
            guard let route else { return }
            rootViewModel.navigate(to: route)
            secureNoteEditorViewModel.clearRoute()
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
        .onChange(of: documentImportViewModel.route) { _, route in
            guard let route else { return }
            rootViewModel.navigate(to: route)
            documentImportViewModel.clearRoute()
        }
        .onChange(of: trashViewModel.route) { _, route in
            guard let route else { return }
            rootViewModel.navigate(to: route)
            trashViewModel.clearRoute()
        }
        .onChange(of: settingsViewModel.route) { _, route in
            guard let route else { return }
            rootViewModel.navigate(to: route)
            settingsViewModel.clearRoute()
        }
        .onChange(of: securityCenterViewModel.route) { _, route in
            guard let route else { return }
            rootViewModel.navigate(to: route)
            securityCenterViewModel.clearRoute()
        }
        .onChange(of: securityCenterViewModel.lockedVaultID) { _, vaultID in
            guard let vaultID else { return }
            rootViewModel.handleLock(vaultID: vaultID)
        }
        .onChange(of: recoverySettingsViewModel.route) { _, route in
            guard let route else { return }
            rootViewModel.navigate(to: route)
            recoverySettingsViewModel.clearRoute()
        }
    }

    @ViewBuilder
    private var routedContent: some View {
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
            ObjectDetailView(
                objectID: objectID,
                vaultID: rootViewModel.activeVaultID,
                viewModel: objectDetailViewModel
            )
        case .objectEditor:
            placeholder(title: "Object Editor", systemImage: "pencil")
        case .secureNoteEditor(let mode):
            SecureNoteEditorView(mode: mode, viewModel: secureNoteEditorViewModel)
        case .identityEditor(let mode):
            IdentityEditorView(mode: mode, viewModel: identityEditorViewModel)
        case .cardEditor(let mode):
            CardEditorView(mode: mode, viewModel: cardEditorViewModel)
        case .importDocument(let vaultID):
            DocumentImportView(vaultID: vaultID, viewModel: documentImportViewModel)
        case .trash(let vaultID):
            TrashView(vaultID: vaultID, viewModel: trashViewModel)
        case .settings(let vaultID):
            SettingsView(vaultID: vaultID, viewModel: settingsViewModel)
        case .securityCenter(let vaultID):
            SecurityCenterView(vaultID: vaultID, viewModel: securityCenterViewModel)
        case .recoverySettings(let vaultID):
            RecoverySettingsView(vaultID: vaultID, viewModel: recoverySettingsViewModel)
        case nil:
            initialLoadingContent
        }
    }

    @ViewBuilder
    private var initialLoadingContent: some View {
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

    private func placeholder(title: String, systemImage: String) -> some View {
        ContentUnavailableView(title, systemImage: systemImage)
    }

    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) async {
        if oldPhase == .background && newPhase != .background {
            await lifecycleCoordinator.handle(.willEnterForeground)
        }

        switch newPhase {
        case .active:
            await lifecycleCoordinator.handle(.didBecomeActive)
        case .inactive:
            await lifecycleCoordinator.handle(.willResignActive)
        case .background:
            await lifecycleCoordinator.handle(.didEnterBackground)
        @unknown default:
            break
        }
    }
}
