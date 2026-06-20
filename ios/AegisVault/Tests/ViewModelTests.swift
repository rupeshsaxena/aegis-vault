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

        XCTAssertEqual(viewModel.state.phase, .unlocked)
        XCTAssertEqual(viewModel.state.unlockedVaultID, vaultID)
    }

    func testUnlockViewModelUnlockFailure() async {
        let useCase = MockUnlockVaultUseCase(result: .failure(TestError.expected))
        let viewModel = UnlockViewModel(unlockVaultUseCase: useCase)

        await viewModel.unlock(vaultID: VaultID("vault"))

        XCTAssertEqual(viewModel.state.phase, .failed)
        XCTAssertNotNil(viewModel.state.errorMessage)
        XCTAssertNil(viewModel.state.unlockedVaultID)
    }

    func testVaultHomeViewModelLoadsObjects() async {
        let summary = makeSummary(title: "Passport")
        let listUseCase = MockListVaultObjectsUseCase(result: .success([summary]))
        let viewModel = makeVaultHomeViewModel(listUseCase: listUseCase)

        await viewModel.loadObjects()

        XCTAssertEqual(viewModel.state.phase, .loaded)
        XCTAssertEqual(viewModel.state.objects, [summary])
        let callCount = await listUseCase.callCount()
        XCTAssertEqual(callCount, 1)
    }

    func testVaultHomeViewModelSearchCallsUseCase() async {
        let result = makeSummary(title: "Travel Card")
        let searchUseCase = MockSearchVaultUseCase(result: .success([result]))
        let viewModel = makeVaultHomeViewModel(searchUseCase: searchUseCase)

        await viewModel.search(query: "travel")

        XCTAssertEqual(viewModel.state.objects, [result])
        let receivedQuery = await searchUseCase.receivedQuery()
        XCTAssertEqual(receivedQuery, "travel")
    }

    private func makeVaultHomeViewModel(
        listUseCase: any ListVaultObjectsUsing = MockListVaultObjectsUseCase(result: .success([])),
        searchUseCase: any SearchVaultUsing = MockSearchVaultUseCase(result: .success([]))
    ) -> VaultHomeViewModel {
        VaultHomeViewModel(
            listVaultObjectsUseCase: listUseCase,
            searchVaultUseCase: searchUseCase,
            lockVaultUseCase: MockLockVaultUseCase()
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

    private func makeSummary(title: String) -> VaultObjectSummary {
        VaultObjectSummary(
            id: VaultObjectID(),
            type: .document,
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

    func execute(vaultID: VaultID, method: UnlockMethod) async throws {
        try result.get()
    }
}

private actor MockListVaultObjectsUseCase: ListVaultObjectsUsing {
    private let result: Result<[VaultObjectSummary], Error>
    private var calls = 0

    init(result: Result<[VaultObjectSummary], Error>) {
        self.result = result
    }

    func execute(filter: VaultObjectFilter) async throws -> [VaultObjectSummary] {
        calls += 1
        return try result.get()
    }

    func callCount() -> Int { calls }
}

private actor MockSearchVaultUseCase: SearchVaultUsing {
    private let result: Result<[VaultObjectSummary], Error>
    private var query: String?

    init(result: Result<[VaultObjectSummary], Error>) {
        self.result = result
    }

    func execute(query: String) async throws -> [VaultObjectSummary] {
        self.query = query
        return try result.get()
    }

    func receivedQuery() -> String? { query }
}

private actor MockLockVaultUseCase: LockVaultUsing {
    func execute(vaultID: VaultID) async {}
}
