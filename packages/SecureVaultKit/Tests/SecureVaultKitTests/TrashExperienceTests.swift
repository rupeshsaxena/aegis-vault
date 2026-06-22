import XCTest
@testable import SecureVaultKit

final class TrashExperienceTests: XCTestCase {
    func testListDeletedObjectsWorks() async throws {
        let (engine, _, objectID) = try await makeTrashedObject()

        let summaries = try await engine.listObjects(
            filter: VaultObjectFilter(includeDeleted: true)
        )

        let summary = try XCTUnwrap(summaries.first { $0.id == objectID })
        XCTAssertTrue(summary.isDeleted)
        XCTAssertNotNil(summary.deletedAt)
    }

    func testRestoreDeletedObjectAppearsInNormalListing() async throws {
        let (engine, _, objectID) = try await makeTrashedObject()

        try await engine.restoreFromTrash(objectID)

        let summaries = try await engine.listObjects(filter: VaultObjectFilter())
        XCTAssertEqual(summaries.map(\.id), [objectID])
        XCTAssertFalse(try XCTUnwrap(summaries.first).isDeleted)
    }

    func testPermanentDeleteRemovesObjectAndAppendsPurgedEvent() async throws {
        let (engine, configuration, objectID) = try await makeTrashedObject()
        let vaultID = try await engine.sessionActor.requireUnlocked().vaultId

        try await engine.permanentlyDeleteObject(objectID)

        await XCTAssertThrowsVaultError(.objectNotFound(objectID)) {
            _ = try await configuration.storageEngine.loadObject(id: objectID)
        }
        let events = try await configuration.eventEngine.listEvents(for: vaultID)
        XCTAssertEqual(
            events.filter { $0.type == .objectPurged && $0.objectId == objectID }.count,
            1
        )
    }

    func testPermanentDeleteRejectsObjectOutsideTrash() async throws {
        let configuration = makeInMemoryConfiguration()
        let engine = DefaultVaultEngine(configuration: configuration)
        _ = try await createVault(using: engine)
        let objectID = try await createNote(using: engine)

        await XCTAssertThrowsVaultError(
            .invalidInput("Only objects in Trash can be permanently deleted.")
        ) {
            try await engine.permanentlyDeleteObject(objectID)
        }

        let detail = try await engine.getObjectDetail(id: objectID)
        XCTAssertEqual(detail.id, objectID)
    }

    func testPurgedObjectNoLongerLoads() async throws {
        let (engine, _, objectID) = try await makeTrashedObject()

        try await engine.permanentlyDeleteObject(objectID)

        await XCTAssertThrowsVaultError(.objectNotFound(objectID)) {
            _ = try await engine.getObjectDetail(id: objectID)
        }
    }

    func testPermanentDeleteFailsWhenLocked() async throws {
        let (engine, _, objectID) = try await makeTrashedObject()
        await engine.lockVault()

        await XCTAssertThrowsVaultError(.locked) {
            try await engine.permanentlyDeleteObject(objectID)
        }
    }

    private func makeTrashedObject() async throws -> (
        DefaultVaultEngine,
        VaultKitConfiguration,
        VaultObjectID
    ) {
        let configuration = makeInMemoryConfiguration()
        let engine = DefaultVaultEngine(configuration: configuration)
        _ = try await createVault(using: engine)
        let objectID = try await createNote(using: engine)
        try await engine.moveToTrash(objectID)
        return (engine, configuration, objectID)
    }

    private func createVault(using engine: DefaultVaultEngine) async throws -> VaultID {
        try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
    }

    private func createNote(using engine: DefaultVaultEngine) async throws -> VaultObjectID {
        try await engine.createObject(
            VaultObjectDraft(
                type: .secureNote,
                metadata: VaultMetadata(title: "Disposable note"),
                payload: VaultPayload(notes: "Private content")
            )
        )
    }
}
