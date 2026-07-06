import XCTest
import SecureVaultKit
@testable import AegisVault

@MainActor
final class AppContainerPersistenceTests: XCTestCase {
    func testAppContainerUsesPersistentLocalEngineFactory() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("App/AppContainer.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("makePersistentLocalEngine"))
        XCTAssertTrue(source.contains("applicationSupportDirectory"))
        XCTAssertFalse(source.contains("makeSimulatorEngine()"))
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
            let engine = try VaultEngineFactory.makePersistentLocalEngine(storageURL: storageURL)
            createdVaultID = try await engine.createVault(
                config: VaultCreationConfig(
                    name: "Persistent App Vault",
                    deviceID: DeviceID("app-persistence-device"),
                    unlockMethod: .recoverySecret("valid-secret")
                )
            )
            await engine.lockVault()
        }

        let reopenedEngine = try VaultEngineFactory.makePersistentLocalEngine(storageURL: storageURL)
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
}
