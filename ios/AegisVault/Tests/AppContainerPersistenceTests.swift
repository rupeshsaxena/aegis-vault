import XCTest
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
}
