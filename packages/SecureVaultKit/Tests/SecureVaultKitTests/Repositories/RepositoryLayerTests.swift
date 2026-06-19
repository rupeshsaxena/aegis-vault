import Foundation
import XCTest
@testable import SecureVaultKit

final class RepositoryLayerTests: XCTestCase {
    func testCreateObjectSucceedsThroughRepositoryLayer() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        let vaultId = try await createVault(using: engine)

        let objectId = try await engine.createObject(makeDraft(title: "Repository create"))

        let record = try await engine.objectRepository.load(id: objectId)
        XCTAssertEqual(record.id, objectId)
        XCTAssertEqual(record.vaultId, vaultId)
        XCTAssertEqual(record.version, 1)
    }

    func testUpdateObjectSucceedsThroughRepositoryLayer() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        _ = try await createVault(using: engine)
        let objectId = try await engine.createObject(makeDraft(title: "Before"))

        _ = try await engine.updateObject(
            VaultObjectUpdate(
                objectId: objectId,
                metadata: VaultMetadata(title: "After"),
                payload: VaultPayload(fields: ["body": .secureText("updated")])
            )
        )

        let record = try await engine.objectRepository.load(id: objectId)
        XCTAssertEqual(record.version, 2)
    }

    func testMoveToTrashSucceedsThroughRepositoryLayer() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        _ = try await createVault(using: engine)
        let objectId = try await engine.createObject(makeDraft(title: "Trash"))

        try await engine.moveToTrash(objectId)

        let record = try await engine.objectRepository.load(id: objectId)
        XCTAssertTrue(record.isDeleted)
        XCTAssertNotNil(record.deletedAt)
    }

    func testRestoreFromTrashSucceedsThroughRepositoryLayer() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        _ = try await createVault(using: engine)
        let objectId = try await engine.createObject(makeDraft(title: "Restore"))
        try await engine.moveToTrash(objectId)

        try await engine.restoreFromTrash(objectId)

        let record = try await engine.objectRepository.load(id: objectId)
        XCTAssertFalse(record.isDeleted)
        XCTAssertNil(record.deletedAt)
    }

    func testEventAppendedOnlyAfterSuccessfulObjectMutation() async throws {
        let storage = InMemoryStorageEngine()
        let events = InMemoryEventEngine()
        let objectRepository = DefaultVaultObjectRepository(storageEngine: storage)
        let eventRepository = DefaultVaultEventRepository(eventEngine: events)
        let coordinator = InMemoryTransactionCoordinator(
            objectRepository: objectRepository,
            eventRepository: eventRepository
        )
        let record = makeRecord()
        await storage.failNextInsert()

        await XCTAssertThrowsVaultError(.unsupportedOperation("Injected storage insert failure.")) {
            try await coordinator.execute(
                .insert(record),
                appending: .objectCreated(vaultId: record.vaultId, objectId: record.id)
            )
        }

        let storedEvents = try await eventRepository.list(for: record.vaultId)
        XCTAssertTrue(storedEvents.isEmpty)
    }

    func testEventFailureRollsBackObjectInsertion() async throws {
        let storage = InMemoryStorageEngine()
        let events = InMemoryEventEngine()
        let objectRepository = DefaultVaultObjectRepository(storageEngine: storage)
        let eventRepository = DefaultVaultEventRepository(eventEngine: events)
        let coordinator = InMemoryTransactionCoordinator(
            objectRepository: objectRepository,
            eventRepository: eventRepository
        )
        let record = makeRecord()
        await events.failNextAppend()

        await XCTAssertThrowsVaultError(.unsupportedOperation("Injected event append failure.")) {
            try await coordinator.execute(
                .insert(record),
                appending: .objectCreated(vaultId: record.vaultId, objectId: record.id)
            )
        }

        await XCTAssertThrowsVaultError(.objectNotFound(record.id)) {
            _ = try await objectRepository.load(id: record.id)
        }
    }

    func testTransactionCoordinatorPreventsPartialCreateObjectState() async throws {
        let storage = InMemoryStorageEngine()
        let events = InMemoryEventEngine()
        let configuration = makeInMemoryConfiguration(storageEngine: storage, eventEngine: events)
        let engine = DefaultVaultEngine(configuration: configuration)
        let vaultId = try await createVault(using: engine)
        await events.failNextAppend()

        await XCTAssertThrowsVaultError(.unsupportedOperation("Injected event append failure.")) {
            _ = try await engine.createObject(makeDraft(title: "Must roll back"))
        }

        let records = try await engine.objectRepository.list(in: vaultId, includeDeleted: true)
        let storedEvents = try await events.listEvents(for: vaultId)
        XCTAssertTrue(records.isEmpty)
        XCTAssertFalse(storedEvents.contains { $0.type == .objectCreated })
    }

    func testRepositoryDoesNotExposePlaintextOnlyModels() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        _ = try await createVault(using: engine)
        let plaintextTitle = "Repository Secret Title"
        let objectId = try await engine.createObject(makeDraft(title: plaintextTitle))

        let record = try await engine.objectRepository.load(id: objectId)
        let persistedMetadata = record.encryptedMetadata.ciphertext

        XCTAssertNil(persistedMetadata.range(of: Data(plaintextTitle.utf8)))
    }

    func testEventRepositoryListsPendingAndObjectEvents() async throws {
        let events = InMemoryEventEngine()
        let repository = DefaultVaultEventRepository(eventEngine: events)
        let vaultId = VaultID("vault-1")
        let objectId = VaultObjectID("object-1")
        let objectEvent = VaultEvent.objectCreated(vaultId: vaultId, objectId: objectId)
        try await repository.append(.vaultCreated(vaultId: vaultId))
        try await repository.append(objectEvent)

        let pending = try await repository.listPending(for: vaultId)
        let objectEvents = try await repository.events(for: objectId, in: vaultId)

        XCTAssertEqual(pending.count, 2)
        XCTAssertEqual(objectEvents, [objectEvent])
    }

    func testSQLiteBackedRepositoryAndCoordinatorPersistAtomically() async throws {
        let databaseURL = makeDatabaseURL()
        defer { try? FileManager.default.removeItem(at: databaseURL.deletingLastPathComponent()) }
        let storage = try SQLiteStorageEngine(databaseURL: databaseURL)
        let header = makeHeader()
        try await storage.createVaultHeader(header)
        let repository = DefaultVaultObjectRepository(storageEngine: storage)
        let events = SQLiteVaultEventRepository(storageEngine: storage)
        let coordinator = SQLiteTransactionCoordinator(storageEngine: storage)
        let record = makeRecord(vaultId: header.vaultId)
        let event = VaultEvent.objectCreated(
            vaultId: header.vaultId,
            objectId: record.id,
            occurredAt: Date(timeIntervalSince1970: 500)
        )

        try await coordinator.execute(.insert(record), appending: event)

        let storedRecord = try await repository.load(id: record.id)
        let storedEvents = try await events.list(for: header.vaultId)
        XCTAssertEqual(storedRecord, record)
        XCTAssertEqual(storedEvents, [event])
    }

    func testSQLiteCoordinatorRollsBackWhenEventPersistenceFails() async throws {
        let databaseURL = makeDatabaseURL()
        defer { try? FileManager.default.removeItem(at: databaseURL.deletingLastPathComponent()) }
        let storage = try SQLiteStorageEngine(databaseURL: databaseURL)
        let header = makeHeader()
        try await storage.createVaultHeader(header)
        let repository = DefaultVaultObjectRepository(storageEngine: storage)
        let coordinator = SQLiteTransactionCoordinator(storageEngine: storage)
        let record = makeRecord(vaultId: header.vaultId)
        let invalidEvent = VaultEvent.objectCreated(
            vaultId: VaultID("missing-vault"),
            objectId: record.id
        )

        do {
            try await coordinator.execute(.insert(record), appending: invalidEvent)
            XCTFail("Expected SQLite event persistence to fail.")
        } catch {
            // The foreign-key failure is expected; the repository assertion verifies rollback.
        }

        await XCTAssertThrowsVaultError(.objectNotFound(record.id)) {
            _ = try await repository.load(id: record.id)
        }
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

    private func makeDraft(title: String) -> VaultObjectDraft {
        VaultObjectDraft(
            type: .secureNote,
            metadata: VaultMetadata(title: title),
            payload: VaultPayload(fields: ["body": .secureText("secret")])
        )
    }

    private func makeRecord(
        vaultId: VaultID = VaultID("vault-1"),
        id: VaultObjectID = VaultObjectID("object-1")
    ) -> VaultObjectRecord {
        VaultObjectRecord(
            id: id,
            vaultId: vaultId,
            type: .secureNote,
            encryptedMetadata: EncryptedEnvelope(
                version: 1,
                algorithm: .aesGCM,
                keyId: "item-key-1",
                nonce: Data([1]),
                ciphertext: Data([2])
            ),
            encryptedPayload: EncryptedEnvelope(
                version: 1,
                algorithm: .aesGCM,
                keyId: "item-key-1",
                nonce: Data([3]),
                ciphertext: Data([4])
            ),
            wrappedItemKey: WrappedKey(
                keyId: "item-key-1",
                wrappingKeyId: "vault-key-1",
                wrappedData: Data([5]),
                algorithm: .aesGCM
            ),
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 200)
        )
    }

    private func makeDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("SecureVaultKit-RepositoryTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("vault.sqlite")
    }

    private func makeHeader() -> VaultHeaderRecord {
        VaultHeaderRecord(
            vaultId: VaultID("vault-1"),
            name: "Primary",
            primaryDeviceId: DeviceID("device-1"),
            rootKey: WrappedKey(
                keyId: "root-key-1",
                wrappingKeyId: "device-key-1",
                wrappedData: Data([1]),
                algorithm: .aesGCM
            ),
            vaultEncryptionKey: WrappedKey(
                keyId: "vault-key-1",
                wrappingKeyId: "root-key-1",
                wrappedData: Data([2]),
                algorithm: .aesGCM
            )
        )
    }
}
