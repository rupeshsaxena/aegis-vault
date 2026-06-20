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
    }

    func testOnboardingViewModelCreateVaultSuccess() async {
        let vaultID = VaultID("created-vault")
        let useCase = MockCreateVaultUseCase(result: .success(vaultID))
        let viewModel = OnboardingViewModel(
            createVaultUseCase: useCase,
            deviceID: DeviceID("device")
        )
        viewModel.setVaultName("Personal")

        await viewModel.createVault()

        XCTAssertEqual(viewModel.state.phase, .created)
        XCTAssertEqual(viewModel.state.createdVaultID, vaultID)
        let receivedName = await useCase.receivedName()
        XCTAssertEqual(receivedName, "Personal")
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

    init(result: Result<VaultID, Error>) {
        self.result = result
    }

    func execute(name: String, deviceID: DeviceID, unlockMethod: UnlockMethod) async throws -> VaultID {
        self.name = name
        return try result.get()
    }

    func receivedName() -> String? { name }
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
