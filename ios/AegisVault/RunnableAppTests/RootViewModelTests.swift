import XCTest
@testable import AegisVault
import SecureVaultKit

final class RootViewModelTests: XCTestCase {
    private static let stubVaultID: VaultID = "test-vault-id"

    @MainActor
    func testRoutesToOnboardingWhenNoVaultExists() async {
        let viewModel = makeViewModel(route: .onboarding)

        await viewModel.determineInitialRoute()

        XCTAssertEqual(viewModel.route, .onboarding)
    }

    @MainActor
    func testRoutesToUnlockWhenVaultExistsAndIsLocked() async {
        let viewModel = makeViewModel(route: .unlock(Self.stubVaultID))

        await viewModel.determineInitialRoute()

        XCTAssertEqual(viewModel.route, .unlock(Self.stubVaultID))
    }

    @MainActor
    func testRoutesToVaultHomeWhenVaultIsUnlocked() async {
        let viewModel = makeViewModel(route: .vaultHome(Self.stubVaultID))

        await viewModel.determineInitialRoute()

        XCTAssertEqual(viewModel.route, .vaultHome(Self.stubVaultID))
    }

    @MainActor
    func testAppContainerCreatesDependencies() async throws {
        let container = AppContainer()

        let status = try await container.vaultEngine.runtimeStatus()
        let viewModel = container.makeRootViewModel()

        XCTAssertEqual(status, .missing)
        XCTAssertNil(viewModel.route)
    }

    func testRootViewModelDoesNotReferenceInfrastructureEngines() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("RunnableApp/RootViewModel.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertFalse(source.contains("StorageEngine"))
        XCTAssertFalse(source.contains("CryptoEngine"))
        XCTAssertFalse(source.contains("BlobStore"))
        XCTAssertFalse(source.contains("import SecureVaultKit"))
    }

    @MainActor
    func testNavigateToRouteUpdatesViewModelRoute() {
        let viewModel = makeViewModel(route: .onboarding)
        let targetRoute: RootRoute = .vaultHome(Self.stubVaultID)

        viewModel.navigate(to: targetRoute)

        XCTAssertEqual(viewModel.route, targetRoute)
    }

    // MARK: - OnboardingViewModel

    @MainActor
    func testOnboardingViewModelCreateVaultSuccess() async throws {
        let vaultID = Self.stubVaultID
        let useCase = StubCreateVaultUseCase(result: .success(vaultID))
        let viewModel = OnboardingViewModel(createVaultUseCase: useCase)
        viewModel.vaultName = "My Vault"

        await viewModel.createVault()

        XCTAssertEqual(viewModel.createdVaultID, vaultID)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isCreating)
    }

    @MainActor
    func testOnboardingViewModelCreateVaultFailure() async {
        let useCase = StubCreateVaultUseCase(result: .failure(VaultError.vaultAlreadyExists))
        let viewModel = OnboardingViewModel(createVaultUseCase: useCase)
        viewModel.vaultName = "My Vault"

        await viewModel.createVault()

        XCTAssertNil(viewModel.createdVaultID)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isCreating)
    }

    @MainActor
    func testCompleteOnboardingSetsCompletedVaultID() async {
        let vaultID = Self.stubVaultID
        let useCase = StubCreateVaultUseCase(result: .success(vaultID))
        let viewModel = OnboardingViewModel(createVaultUseCase: useCase)
        viewModel.vaultName = "My Vault"

        await viewModel.createVault()
        viewModel.completeOnboarding()

        XCTAssertEqual(viewModel.completedVaultID, vaultID)
    }

    // MARK: - VaultHomeViewModel

    @MainActor
    func testVaultHomeViewModelEmptyState() async {
        let useCase = StubListVaultObjectsUseCase(objects: [])
        let viewModel = VaultHomeViewModel(listVaultObjectsUseCase: useCase)

        await viewModel.loadObjects()

        XCTAssertTrue(viewModel.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }

    // MARK: - Helpers

    @MainActor
    private func makeViewModel(route: RootRoute) -> RootViewModel {
        RootViewModel(resolveRootRouteUseCase: StubResolveRootRouteUseCase(route: route))
    }
}

// MARK: - Stubs

private struct StubResolveRootRouteUseCase: ResolveRootRouteUsing {
    let route: RootRoute

    func execute() async throws -> RootRoute {
        route
    }
}

private struct StubCreateVaultUseCase: CreateVaultUsing {
    let result: Result<VaultID, Error>

    func execute(name: String, deviceID: DeviceID, unlockMethod: UnlockMethod) async throws -> VaultID {
        try result.get()
    }
}

private struct StubListVaultObjectsUseCase: ListVaultObjectsUsing {
    let objects: [VaultObjectSummary]

    func execute(filter: VaultObjectFilter) async throws -> [VaultObjectSummary] {
        objects
    }
}
