import XCTest
import SecureVaultKit
@testable import AegisVault

@MainActor
final class AppContainerPersistenceTests: XCTestCase {
    func testAppContainerUsesPersistentLocalEngineFactory() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("App/AppDependencyFactory.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("makePersistentLocalEngine"))
        XCTAssertTrue(source.contains("applicationSupportDirectory"))
        XCTAssertFalse(source.contains("makeSimulatorEngine()"))
    }

    func testAppContainerCreatesSuccessfully() throws {
        let container = try AppContainer(
            environment: makeTestEnvironment(),
            dependencyFactory: try makeDependencyFactory()
        )

        XCTAssertNotNil(container.viewModelFactory)
        XCTAssertNotNil(container.serviceFactory)
    }

    func testAppDependencyFactoryCreatesVaultEngine() throws {
        let storageURL = try makeTemporaryStorageURL()
        let dependencyFactory = AppDependencyFactory(
            environment: AppEnvironment(
                runtime: .debug,
                storageDirectoryName: storageURL.lastPathComponent
            ),
            applicationSupportURL: storageURL.deletingLastPathComponent()
        )

        let engine = try dependencyFactory.makeVaultEngine()

        XCTAssertNotNil(engine)
        XCTAssertTrue(FileManager.default.fileExists(atPath: storageURL.path))
    }

    func testFeatureServiceFactoryCreatesServices() throws {
        let engine = try makeEngine()
        let factory = FeatureServiceFactory(vaultEngine: engine)

        XCTAssertNotNil(factory.makeSecureNoteService())
        XCTAssertNotNil(factory.makeIdentityService())
        XCTAssertNotNil(factory.makeCardService())
        XCTAssertNotNil(factory.makeDocumentService())
        XCTAssertNotNil(factory.makeTrashService())
    }

    func testViewModelFactoryCreatesViewModels() throws {
        let engine = try makeEngine()
        let serviceFactory = FeatureServiceFactory(vaultEngine: engine)
        let factory = ViewModelFactory(vaultEngine: engine, featureServiceFactory: serviceFactory)

        XCTAssertNotNil(factory.makeRootViewModel())
        XCTAssertNotNil(factory.makeOnboardingViewModel())
        XCTAssertNotNil(factory.makeUnlockViewModel())
        XCTAssertNotNil(factory.makeVaultHomeViewModel())
        XCTAssertNotNil(factory.makeSecureNoteEditorViewModel())
        XCTAssertNotNil(factory.makeIdentityEditorViewModel())
        XCTAssertNotNil(factory.makeCardEditorViewModel())
        XCTAssertNotNil(factory.makeDocumentImportViewModel())
        XCTAssertNotNil(factory.makeTrashViewModel())
    }

    func testRootFlowStillBuildsThroughContainerFacade() throws {
        let container = try AppContainer(
            environment: makeTestEnvironment(),
            dependencyFactory: try makeDependencyFactory()
        )

        XCTAssertNotNil(RootView(container: container))
    }

    func testRootRoutingUsesVaultEngineRuntimeStatusThroughUseCase() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Application/UseCases/ResolveAppRouteUseCase.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("vaultEngine.runtimeStatus()"))
        XCTAssertFalse(source.contains("UserDefaults"))
        XCTAssertFalse(source.contains("StorageEngine"))
        XCTAssertFalse(source.contains("SQLiteStorageEngine"))
    }

    func testRootRouteDetectsExistingVaultAfterEngineRecreation() async throws {
        let storageURL = try makeTemporaryStorageURL()
        let createdVaultID: VaultID
        do {
            let engine = try makeEngine(storageURL: storageURL)
            createdVaultID = try await engine.createVault(
                config: VaultCreationConfig(
                    name: "Persistent App Vault",
                    deviceID: DeviceID("app-persistence-device"),
                    unlockMethod: .recoverySecret("valid-secret")
                )
            )
            await engine.lockVault()
        }

        let reopenedEngine = try makeEngine(storageURL: storageURL)
        let route = try await ResolveAppRouteUseCase(vaultEngine: reopenedEngine).execute()

        XCTAssertEqual(route, .unlock(createdVaultID))
    }

    private func makeTemporaryStorageURL() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("AegisVaultAppPersistenceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }

    private func makeEngine(storageURL: URL? = nil) throws -> any VaultEngine {
        let storageURL = try storageURL ?? makeTemporaryStorageURL()
        return try makeDependencyFactory(storageURL: storageURL).makeVaultEngine()
    }

    private func makeDependencyFactory(storageURL: URL? = nil) throws -> AppDependencyFactory {
        let storageURL = try storageURL ?? makeTemporaryStorageURL()
        return AppDependencyFactory(
            environment: AppEnvironment(
                runtime: .debug,
                storageDirectoryName: storageURL.lastPathComponent
            ),
            applicationSupportURL: storageURL.deletingLastPathComponent()
        )
    }

    private func makeTestEnvironment() -> AppEnvironment {
        AppEnvironment(runtime: .debug)
    }
}
