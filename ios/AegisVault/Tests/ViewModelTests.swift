import XCTest
import SecureVaultKit
@testable import AegisVault

@MainActor
final class ViewModelTests: XCTestCase {
    func testOnboardingViewModelInitialState() {
        let viewModel = OnboardingViewModel(
            createVaultUseCase: MockCreateVaultUseCase(result: .success(VaultID("vault")))
        )

        XCTAssertEqual(viewModel.state, OnboardingState())
        XCTAssertEqual(viewModel.state.step, .welcome)
    }

    func testOnboardingNextMovesToNextStep() {
        let viewModel = makeOnboardingViewModel()

        viewModel.next()

        XCTAssertEqual(viewModel.state.step, .securityPrinciples)
    }

    func testOnboardingBackMovesToPreviousStep() {
        let viewModel = makeOnboardingViewModel()
        viewModel.next()
        viewModel.next()

        viewModel.back()

        XCTAssertEqual(viewModel.state.step, .securityPrinciples)
    }

    func testOnboardingViewModelCreateVaultSuccess() async {
        let vaultID = VaultID("created-vault")
        let useCase = MockCreateVaultUseCase(result: .success(vaultID))
        let viewModel = OnboardingViewModel(
            createVaultUseCase: useCase,
            deviceID: DeviceID("device")
        )
        advanceToCreateVault(viewModel)
        viewModel.setVaultName("Personal")

        await viewModel.createVault()

        XCTAssertEqual(viewModel.state.phase, .created)
        XCTAssertEqual(viewModel.state.createdVaultID, vaultID)
        XCTAssertEqual(viewModel.state.step, .recoveryPackage)
        let receivedName = await useCase.receivedName()
        XCTAssertEqual(receivedName, "Personal")
    }

    func testOnboardingCreateVaultCallsUseCase() async {
        let useCase = MockCreateVaultUseCase(result: .success(VaultID("vault")))
        let viewModel = OnboardingViewModel(createVaultUseCase: useCase)
        advanceToCreateVault(viewModel)
        viewModel.setVaultName("Primary")

        await viewModel.createVault()

        let callCount = await useCase.callCount()
        XCTAssertEqual(callCount, 1)
    }

    func testOnboardingCreateVaultFailureUpdatesErrorState() async {
        let viewModel = OnboardingViewModel(
            createVaultUseCase: MockCreateVaultUseCase(result: .failure(TestError.expected))
        )
        advanceToCreateVault(viewModel)
        viewModel.setVaultName("Primary")

        await viewModel.createVault()

        XCTAssertEqual(viewModel.state.phase, .failed)
        XCTAssertEqual(viewModel.state.step, .createVault)
        XCTAssertNotNil(viewModel.state.errorMessage)
        XCTAssertNil(viewModel.state.createdVaultID)
    }

    func testRecoveryWarningMustBeAcknowledgedBeforeCompletion() async {
        let vaultID = VaultID("vault")
        let viewModel = OnboardingViewModel(
            createVaultUseCase: MockCreateVaultUseCase(result: .success(vaultID))
        )
        advanceToCreateVault(viewModel)
        viewModel.setVaultName("Primary")
        await viewModel.createVault()

        viewModel.next()

        XCTAssertEqual(viewModel.state.step, .recoveryPackage)
        XCTAssertNil(viewModel.state.completedVaultID)

        viewModel.setRecoveryWarningAcknowledged(true)
        viewModel.next()
        viewModel.skipBiometricSetup()
        viewModel.next()

        XCTAssertEqual(viewModel.state.completedVaultID, vaultID)
    }

    func testBiometricPlaceholderCanBeSkipped() async {
        let viewModel = OnboardingViewModel(
            createVaultUseCase: MockCreateVaultUseCase(result: .success(VaultID("vault")))
        )
        advanceToCreateVault(viewModel)
        viewModel.setVaultName("Primary")
        await viewModel.createVault()
        viewModel.setRecoveryWarningAcknowledged(true)
        viewModel.next()

        viewModel.skipBiometricSetup()

        XCTAssertTrue(viewModel.state.biometricSetupSkipped)
        XCTAssertEqual(viewModel.state.step, .completion)
    }

    func testUnlockViewModelUnlockSuccess() async {
        let useCase = MockUnlockVaultUseCase(result: .success(()))
        let viewModel = UnlockViewModel(unlockVaultUseCase: useCase)
        let vaultID = VaultID("vault")

        await viewModel.unlock(vaultID: vaultID, method: .passkey)

        XCTAssertEqual(viewModel.state, .unlocked(vaultID))
        XCTAssertEqual(viewModel.state.unlockedVaultID, vaultID)
    }

    func testUnlockViewModelInitialStateIsIdle() {
        let viewModel = UnlockViewModel(
            unlockVaultUseCase: MockUnlockVaultUseCase(result: .success(()))
        )

        XCTAssertEqual(viewModel.state, .idle)
    }

    func testUnlockViewModelUnlockFailure() async {
        let useCase = MockUnlockVaultUseCase(result: .failure(TestError.expected))
        let viewModel = UnlockViewModel(unlockVaultUseCase: useCase)

        await viewModel.unlock(vaultID: VaultID("vault"))

        XCTAssertEqual(viewModel.state, .failed("Unable to unlock vault."))
        XCTAssertNotNil(viewModel.state.errorMessage)
        XCTAssertNil(viewModel.state.unlockedVaultID)
    }

    func testBiometricUnlockSuccessRoutesToVaultHome() async {
        let vaultID = VaultID("vault")
        let viewModel = UnlockViewModel(
            unlockVaultUseCase: MockUnlockVaultUseCase(result: .success(()))
        )

        await viewModel.unlock(vaultID: vaultID, method: .biometric)

        XCTAssertEqual(viewModel.state, .unlocked(vaultID))
    }

    func testBiometricUnlockFailureShowsSafeMessage() async {
        let viewModel = UnlockViewModel(
            unlockVaultUseCase: MockUnlockVaultUseCase(result: .failure(VaultError.biometricUnavailable))
        )

        await viewModel.unlock(vaultID: VaultID("vault"), method: .biometric)

        XCTAssertEqual(viewModel.state, .failed("Biometric unlock is unavailable."))
    }

    func testCancelledBiometricUnlockShowsSafeCancelledState() async {
        let viewModel = UnlockViewModel(
            unlockVaultUseCase: MockUnlockVaultUseCase(result: .failure(VaultError.authenticationCancelled))
        )

        await viewModel.unlock(vaultID: VaultID("vault"), method: .biometric)

        XCTAssertEqual(viewModel.state, .failed("Unlock was cancelled."))
    }

    func testUnlockViewModelShowsLoadingDuringUnlock() async {
        let useCase = SuspendingUnlockVaultUseCase()
        let viewModel = UnlockViewModel(unlockVaultUseCase: useCase)
        let task = Task {
            await viewModel.unlock(vaultID: VaultID("vault"), method: .biometric)
        }
        await useCase.waitUntilStarted()

        XCTAssertEqual(viewModel.state, .unlocking)

        await useCase.succeed()
        await task.value
    }

    func testUnlockErrorMappingIsUserSafe() {
        XCTAssertEqual(
            UnlockViewModel.userMessage(for: VaultError.locked),
            "Your vault is locked."
        )
        XCTAssertEqual(
            UnlockViewModel.userMessage(for: VaultError.authenticationFailed),
            "Authentication failed. Please try again."
        )
        XCTAssertEqual(
            UnlockViewModel.userMessage(for: VaultError.vaultNotFound(VaultID("missing"))),
            "No vault was found on this device."
        )
        XCTAssertEqual(
            UnlockViewModel.userMessage(for: TestError.expected),
            "Unable to unlock vault."
        )
        XCTAssertEqual(
            UnlockViewModel.userMessage(for: VaultError.biometricUnavailable),
            "Biometric unlock is unavailable."
        )
        XCTAssertEqual(
            UnlockViewModel.userMessage(for: VaultError.authenticationCancelled),
            "Unlock was cancelled."
        )
        XCTAssertEqual(
            UnlockViewModel.userMessage(for: VaultError.biometricLockedOut),
            "Biometric authentication is locked. Use device passcode."
        )
    }

    func testUnlockViewModelDoesNotAccessPlatformAuthenticationOrKeys() throws {
        let testsURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let sourceURL = testsURL
            .deletingLastPathComponent()
            .appendingPathComponent("Presentation/Unlock/UnlockViewModel.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertFalse(source.contains("LocalAuthentication"))
        XCTAssertFalse(source.contains("LAContext"))
        XCTAssertFalse(source.contains("Keychain"))
        XCTAssertFalse(source.contains("SecureEnclave"))
        XCTAssertFalse(source.contains("CryptoEngine"))
        XCTAssertFalse(source.contains("KeyMaterial"))
    }

    func testRootFlowRoutesToVaultHomeAfterUnlockSuccess() async {
        let vaultID = VaultID("vault")
        let unlockViewModel = UnlockViewModel(
            unlockVaultUseCase: MockUnlockVaultUseCase(result: .success(()))
        )
        let rootViewModel = RootViewModel(
            resolveAppRouteUseCase: MockResolveAppRouteUseCase(route: .unlock(vaultID))
        )
        await rootViewModel.resolveInitialRoute()
        await unlockViewModel.unlock(vaultID: vaultID)

        if let unlockedVaultID = unlockViewModel.state.unlockedVaultID {
            rootViewModel.handleUnlockSuccess(vaultID: unlockedVaultID)
        }

        XCTAssertEqual(rootViewModel.route, .vaultHome(vaultID))
    }

    func testRootViewModelRoutesToOnboardingWhenNoVaultExists() async {
        let viewModel = RootViewModel(
            resolveAppRouteUseCase: MockResolveAppRouteUseCase(route: .onboarding)
        )

        await viewModel.resolveInitialRoute()

        XCTAssertEqual(viewModel.route, .onboarding)
        XCTAssertNil(viewModel.activeVaultID)
    }

    func testRootViewModelRoutesToUnlockWhenPersistedVaultExistsAndSessionLocked() async {
        let vaultID = VaultID("persisted-vault")
        let viewModel = RootViewModel(
            resolveAppRouteUseCase: MockResolveAppRouteUseCase(route: .unlock(vaultID))
        )

        await viewModel.resolveInitialRoute()

        XCTAssertEqual(viewModel.route, .unlock(vaultID))
        XCTAssertEqual(viewModel.activeVaultID, vaultID)
    }

    func testRootViewModelRoutesToVaultHomeWhenSessionUnlocked() async {
        let vaultID = VaultID("active-vault")
        let viewModel = RootViewModel(
            resolveAppRouteUseCase: MockResolveAppRouteUseCase(route: .vaultHome(vaultID))
        )

        await viewModel.resolveInitialRoute()

        XCTAssertEqual(viewModel.route, .vaultHome(vaultID))
        XCTAssertEqual(viewModel.activeVaultID, vaultID)
    }

    func testVaultHomeViewModelInitialStateIsLoading() {
        let viewModel = makeVaultHomeViewModel()

        XCTAssertEqual(viewModel.state, .loading)
    }

    func testVaultHomeViewModelLoadSuccess() async {
        let summary = makeSummary(title: "Passport")
        let listUseCase = MockListVaultObjectsUseCase(result: .success([summary]))
        let viewModel = makeVaultHomeViewModel(listUseCase: listUseCase)

        await viewModel.loadObjects()

        XCTAssertEqual(
            viewModel.state,
            .loaded([VaultObjectSummaryViewData(summary: summary)])
        )
        let callCount = await listUseCase.callCount()
        XCTAssertEqual(callCount, 1)
    }

    func testVaultHomeViewModelLoadEmpty() async {
        let viewModel = makeVaultHomeViewModel()

        await viewModel.loadObjects()

        XCTAssertEqual(
            viewModel.state,
            .empty(VaultHomeEmptyState(title: "No items yet", suggestion: "Add your first vault item"))
        )
    }

    func testVaultHomeViewModelLoadFailure() async {
        let viewModel = makeVaultHomeViewModel(
            listUseCase: MockListVaultObjectsUseCase(result: .failure(TestError.expected))
        )

        await viewModel.loadObjects()

        XCTAssertEqual(viewModel.state, .error("Unable to load vault items."))
    }

    func testVaultHomeViewModelSearchSuccess() async {
        let result = makeSummary(title: "Travel Card")
        let searchUseCase = MockSearchVaultUseCase(result: .success([result]))
        let viewModel = makeVaultHomeViewModel(searchUseCase: searchUseCase)

        await viewModel.search(query: "travel")

        XCTAssertEqual(viewModel.state, .loaded([VaultObjectSummaryViewData(summary: result)]))
        let receivedQuery = await searchUseCase.receivedQuery()
        XCTAssertEqual(receivedQuery, "travel")
    }

    func testVaultHomeViewModelSearchNoResults() async {
        let viewModel = makeVaultHomeViewModel()

        await viewModel.search(query: "missing")

        XCTAssertEqual(
            viewModel.state,
            .empty(VaultHomeEmptyState(title: "No results", suggestion: "Try another search or filter."))
        )
    }

    func testVaultHomeViewModelFiltersByType() async {
        let searchUseCase = MockSearchVaultUseCase(result: .success([]))
        let viewModel = makeVaultHomeViewModel(searchUseCase: searchUseCase)
        await viewModel.search(query: "travel")

        await viewModel.selectFilter(.documents)

        XCTAssertEqual(viewModel.selectedFilter, .documents)
        let receivedFilter = await searchUseCase.receivedFilter()
        XCTAssertEqual(receivedFilter?.types, [.document])
        XCTAssertEqual(receivedFilter?.includeDeleted, false)
    }

    func testVaultHomeViewModelClearsFilter() async {
        let listUseCase = MockListVaultObjectsUseCase(result: .success([]))
        let viewModel = makeVaultHomeViewModel(listUseCase: listUseCase)
        await viewModel.selectFilter(.photos)

        await viewModel.clearFilter()

        XCTAssertEqual(viewModel.selectedFilter, .all)
        let receivedFilter = await listUseCase.receivedFilter()
        XCTAssertEqual(receivedFilter?.types, [])
    }

    func testVaultHomeViewModelSearchWhileLockedFails() async {
        let viewModel = makeVaultHomeViewModel(
            searchUseCase: MockSearchVaultUseCase(result: .failure(VaultError.locked))
        )

        await viewModel.search(query: "passport")

        XCTAssertEqual(viewModel.state, .error("Unlock your vault to search."))
    }

    func testVaultHomeObjectSelectionTriggersRoute() {
        let viewModel = makeVaultHomeViewModel()
        let objectID = VaultObjectID("passport")

        viewModel.selectObject(id: objectID)

        XCTAssertEqual(viewModel.route, .objectDetail(objectID))
    }

    func testVaultHomeAddRoutesToIdentityEditor() {
        let viewModel = makeVaultHomeViewModel()
        let vaultID = VaultID("vault")

        viewModel.addItem(to: vaultID)

        XCTAssertEqual(viewModel.route, .identityEditor(.create(vaultID)))
    }

    func testVaultHomeAddCardRoutesToCardEditor() {
        let viewModel = makeVaultHomeViewModel()
        let vaultID = VaultID("vault")

        viewModel.addCard(to: vaultID)

        XCTAssertEqual(viewModel.route, .cardEditor(.create(vaultID)))
    }

    func testVaultHomeViewModelCanRequestThumbnail() async {
        let objectID = VaultObjectID("document")
        let thumbnail = VaultThumbnail(
            objectId: objectID,
            data: Data("thumbnail".utf8),
            contentType: "image/png"
        )
        let viewModel = makeVaultHomeViewModel(
            thumbnailUseCase: MockLoadThumbnailUseCase(result: .success(thumbnail))
        )

        await viewModel.loadThumbnail(for: objectID)

        XCTAssertEqual(
            viewModel.thumbnailStates[objectID],
            .loaded(ThumbnailViewData(data: thumbnail.data, contentType: "image/png"))
        )
    }

    func testVaultHomeThumbnailFailureFallsBackToPlaceholder() async {
        let objectID = VaultObjectID("document")
        let viewModel = makeVaultHomeViewModel(
            thumbnailUseCase: MockLoadThumbnailUseCase(result: .failure(TestError.expected))
        )

        await viewModel.loadThumbnail(for: objectID)

        XCTAssertEqual(viewModel.thumbnailStates[objectID], .placeholder)
    }

    private func makeVaultHomeViewModel(
        listUseCase: any ListVaultObjectsUsing = MockListVaultObjectsUseCase(result: .success([])),
        searchUseCase: any SearchVaultUsing = MockSearchVaultUseCase(result: .success([])),
        thumbnailUseCase: any LoadThumbnailUsing = MockLoadThumbnailUseCase(
            result: .failure(VaultError.thumbnailNotFound(VaultObjectID("missing")))
        )
    ) -> VaultHomeViewModel {
        VaultHomeViewModel(
            listVaultObjectsUseCase: listUseCase,
            searchVaultUseCase: searchUseCase,
            lockVaultUseCase: MockLockVaultUseCase(),
            loadThumbnailUseCase: thumbnailUseCase
        )
    }

    private func makeOnboardingViewModel() -> OnboardingViewModel {
        OnboardingViewModel(
            createVaultUseCase: MockCreateVaultUseCase(result: .success(VaultID("vault")))
        )
    }

    private func advanceToCreateVault(_ viewModel: OnboardingViewModel) {
        viewModel.next()
        viewModel.next()
        XCTAssertEqual(viewModel.state.step, .createVault)
    }

    private func makeSummary(
        title: String,
        type: VaultObjectType = .document
    ) -> VaultObjectSummary {
        VaultObjectSummary(
            id: VaultObjectID(),
            type: type,
            title: title,
            updatedAt: Date(timeIntervalSince1970: 100)
        )
    }
}

private enum TestError: Error {
    case expected
}

private actor MockCreateVaultUseCase: CreateVaultUsing {
    private let result: Result<VaultID, Error>
    private var name: String?
    private var calls = 0

    init(result: Result<VaultID, Error>) {
        self.result = result
    }

    func execute(name: String, deviceID: DeviceID, unlockMethod: UnlockMethod) async throws -> VaultID {
        calls += 1
        self.name = name
        return try result.get()
    }

    func receivedName() -> String? { name }
    func callCount() -> Int { calls }
}

private actor MockUnlockVaultUseCase: UnlockVaultUsing {
    private let result: Result<Void, Error>

    init(result: Result<Void, Error>) {
        self.result = result
    }

    func execute(method: UnlockMethod) async throws {
        try result.get()
    }
}

private actor SuspendingUnlockVaultUseCase: UnlockVaultUsing {
    private var started = false
    private var continuation: CheckedContinuation<Void, Error>?

    func execute(method: UnlockMethod) async throws {
        started = true
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func waitUntilStarted() async {
        while !started {
            await Task.yield()
        }
    }

    func succeed() {
        continuation?.resume()
        continuation = nil
    }
}

private struct MockResolveAppRouteUseCase: ResolveAppRouteUsing {
    let route: AppRoute

    func execute() async throws -> AppRoute {
        route
    }
}

private actor MockListVaultObjectsUseCase: ListVaultObjectsUsing {
    private let result: Result<[VaultObjectSummary], Error>
    private var calls = 0
    private var filter: VaultObjectFilter?

    init(result: Result<[VaultObjectSummary], Error>) {
        self.result = result
    }

    func execute(filter: VaultObjectFilter) async throws -> [VaultObjectSummary] {
        calls += 1
        self.filter = filter
        return try result.get()
    }

    func callCount() -> Int { calls }
    func receivedFilter() -> VaultObjectFilter? { filter }
}

private actor MockSearchVaultUseCase: SearchVaultUsing {
    private let result: Result<[VaultObjectSummary], Error>
    private var query: String?
    private var filter: VaultObjectFilter?

    init(result: Result<[VaultObjectSummary], Error>) {
        self.result = result
    }

    func execute(query: String, filter: VaultObjectFilter) async throws -> [VaultObjectSummary] {
        self.query = query
        self.filter = filter
        return try result.get()
    }

    func receivedQuery() -> String? { query }
    func receivedFilter() -> VaultObjectFilter? { filter }
}

private actor MockLockVaultUseCase: LockVaultUsing {
    func execute(vaultID: VaultID) async {}
}

private actor MockLoadThumbnailUseCase: LoadThumbnailUsing {
    private let result: Result<VaultThumbnail, Error>

    init(result: Result<VaultThumbnail, Error>) {
        self.result = result
    }

    func execute(objectId: VaultObjectID) async throws -> VaultThumbnail {
        try result.get()
    }
}
