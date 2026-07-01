import XCTest
@testable import SecureVaultKit

final class VaultEngineFactoryTests: XCTestCase {
    func testBootstrapEngineReportsMissingVault() async throws {
        let engine = VaultEngineFactory.makeBootstrapEngine()

        let status = try await engine.runtimeStatus()

        XCTAssertEqual(status, .missing)
    }

    func testBootstrapEngineRejectsProductOperations() async {
        let engine = VaultEngineFactory.makeBootstrapEngine()

        do {
            _ = try await engine.listObjects(filter: VaultObjectFilter())
            XCTFail("Expected the bootstrap engine to reject product operations.")
        } catch let error as VaultError {
            guard case .unsupportedOperation = error else {
                return XCTFail("Expected unsupportedOperation, received \(error).")
            }
        } catch {
            XCTFail("Expected VaultError, received \(error).")
        }
    }

    func testPersistentLocalEngineCreatesStableStorage() async throws {
        let storageURL = try makeTemporaryStorageURL()

        _ = try VaultEngineFactory.makePersistentLocalEngine(storageURL: storageURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: storageURL.path))
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: storageURL.appendingPathComponent("vault.sqlite").path
            )
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: storageURL.appendingPathComponent("blobs").path
            )
        )
    }

    func testPersistentLocalEngineVaultHeaderSurvivesEngineRecreation() async throws {
        let storageURL = try makeTemporaryStorageURL()
        let createdVaultId: VaultID
        do {
            let engine = try VaultEngineFactory.makePersistentLocalEngine(storageURL: storageURL)
            createdVaultId = try await engine.createVault(config: persistentTestVaultConfig())
        }

        let reopenedEngine = try VaultEngineFactory.makePersistentLocalEngine(storageURL: storageURL)
        let status = try await reopenedEngine.runtimeStatus()

        XCTAssertEqual(status, .locked(createdVaultId))
    }

    func testPersistentLocalEngineObjectSurvivesEngineRecreation() async throws {
        let storageURL = try makeTemporaryStorageURL()
        let createdObjectId: VaultObjectID
        do {
            let engine = try VaultEngineFactory.makePersistentLocalEngine(storageURL: storageURL)
            _ = try await engine.createVault(config: persistentTestVaultConfig())
            createdObjectId = try await engine.createObject(persistentTestNoteDraft(title: "Relaunch Note"))
            await engine.lockVault()
        }

        let reopenedEngine = try VaultEngineFactory.makePersistentLocalEngine(storageURL: storageURL)
        try await reopenedEngine.unlockVault(method: .recoverySecret("valid-secret"))
        let summaries = try await reopenedEngine.listObjects(filter: VaultObjectFilter())
        let detail = try await reopenedEngine.getObjectDetail(id: createdObjectId)

        XCTAssertEqual(summaries.map(\.id), [createdObjectId])
        XCTAssertEqual(summaries.first?.title, "Relaunch Note")
        XCTAssertEqual(detail.payload.notes, "This note should survive engine recreation.")
    }

    func testPersistentLocalEngineDeletedObjectStateSurvivesEngineRecreation() async throws {
        let storageURL = try makeTemporaryStorageURL()
        let deletedObjectId: VaultObjectID
        do {
            let engine = try VaultEngineFactory.makePersistentLocalEngine(storageURL: storageURL)
            _ = try await engine.createVault(config: persistentTestVaultConfig())
            deletedObjectId = try await engine.createObject(persistentTestNoteDraft(title: "Deleted Note"))
            try await engine.moveToTrash(deletedObjectId)
            await engine.lockVault()
        }

        let reopenedEngine = try VaultEngineFactory.makePersistentLocalEngine(storageURL: storageURL)
        try await reopenedEngine.unlockVault(method: .recoverySecret("valid-secret"))
        let visibleObjects = try await reopenedEngine.listObjects(filter: VaultObjectFilter())
        let deletedObjects = try await reopenedEngine.listObjects(
            filter: VaultObjectFilter(includeDeleted: true)
        )

        XCTAssertFalse(visibleObjects.contains { $0.id == deletedObjectId })
        XCTAssertTrue(deletedObjects.contains { $0.id == deletedObjectId && $0.isDeleted })
    }

    private func makeTemporaryStorageURL() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SecureVaultKitPersistentFactoryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }

    private func persistentTestVaultConfig() -> VaultCreationConfig {
        VaultCreationConfig(
            name: "Persistent Test Vault",
            deviceID: DeviceID("persistent-test-device"),
            unlockMethod: .recoverySecret("valid-secret")
        )
    }

    private func persistentTestNoteDraft(title: String) -> VaultObjectDraft {
        VaultObjectDraft(
            type: .secureNote,
            metadata: VaultMetadata(title: title, tags: ["persistence"]),
            payload: VaultPayload(notes: "This note should survive engine recreation.")
        )
    }
}
