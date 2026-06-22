import XCTest
@testable import AegisVault
import SecureVaultKit

final class RootViewModelTests: XCTestCase {
    @MainActor
    func testRoutesToOnboardingWhenNoVaultExists() async {
        let viewModel = makeViewModel(route: .onboarding)

        await viewModel.determineInitialRoute()

        XCTAssertEqual(viewModel.route, .onboarding)
    }

    @MainActor
    func testRoutesToUnlockWhenVaultExistsAndIsLocked() async {
        let viewModel = makeViewModel(route: .unlock)

        await viewModel.determineInitialRoute()

        XCTAssertEqual(viewModel.route, .unlock)
    }

    @MainActor
    func testRoutesToVaultHomeWhenVaultIsUnlocked() async {
        let viewModel = makeViewModel(route: .vaultHome)

        await viewModel.determineInitialRoute()

        XCTAssertEqual(viewModel.route, .vaultHome)
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
    private func makeViewModel(route: RootRoute) -> RootViewModel {
        RootViewModel(resolveRootRouteUseCase: StubResolveRootRouteUseCase(route: route))
    }
}

private struct StubResolveRootRouteUseCase: ResolveRootRouteUsing {
    let route: RootRoute

    func execute() async throws -> RootRoute {
        route
    }
}

