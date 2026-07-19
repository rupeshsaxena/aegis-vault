import Foundation
import SQLite3
import XCTest
@testable import SecureVaultKit

final class SQLiteStorageEngineTests: XCTestCase {
    func testSQLiteCreatesDatabase() throws {
        let databaseURL = makeDatabaseURL()
        defer { removeDatabaseDirectory(databaseURL) }

        _ = try SQLiteStorageEngine(databaseURL: databaseURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: databaseURL.path))
    }

    func testSQLiteRunsMigrations() async throws {
        let databaseURL = makeDatabaseURL()
        defer { removeDatabaseDirectory(databaseURL) }
        let storage = try SQLiteStorageEngine(databaseURL: databaseURL)

        let migrations = try await storage.migrationIdentifiers()
        let tables = try await storage.schemaTableNames()

        XCTAssertEqual(migrations, ["v1", "v2"])
        XCTAssertTrue(Set([
            "vault_headers",
            "vault_objects",
            "vault_attachments",
            "vault_events",
            "trusted_devices",
            "blob_records",
            "sync_journal"
        ]).isSubset(of: Set(tables)))
    }

    func testSQLitePersistsVaultHeader() async throws {
        let databaseURL = makeDatabaseURL()
        defer { removeDatabaseDirectory(databaseURL) }
        let storage = try SQLiteStorageEngine(databaseURL: databaseURL)
        let header = makeHeader()

        try await storage.createVaultHeader(header)

        let storedHeader = try await storage.loadVaultHeader(vaultId: header.vaultId)
        XCTAssertEqual(storedHeader, header)
    }

    func testSQLiteLoadsVaultHeaderAfterReopen() async throws {
        let databaseURL = makeDatabaseURL()
        defer { removeDatabaseDirectory(databaseURL) }
        let header = makeHeader()
        do {
            let storage = try SQLiteStorageEngine(databaseURL: databaseURL)
            try await storage.createVaultHeader(header)
        }

        let reopenedStorage = try SQLiteStorageEngine(databaseURL: databaseURL)

        let storedHeader = try await reopenedStorage.loadVaultHeader(vaultId: header.vaultId)
        XCTAssertEqual(storedHeader, header)
    }

    func testSQLitePersistsObject() async throws {
        let databaseURL = makeDatabaseURL()
        defer { removeDatabaseDirectory(databaseURL) }
        let storage = try SQLiteStorageEngine(databaseURL: databaseURL)
        let header = makeHeader()
        let object = try await makeObject(vaultId: header.vaultId)
        try await storage.createVaultHeader(header)

        try await storage.insertObject(object)

        let storedObject = try await storage.loadObject(id: object.id)
        XCTAssertEqual(storedObject, object)
    }

    func testSQLiteLoadsObjectAfterReopen() async throws {
        let databaseURL = makeDatabaseURL()
        defer { removeDatabaseDirectory(databaseURL) }
        let header = makeHeader()
        let object = try await makeObject(vaultId: header.vaultId)
        do {
            let storage = try SQLiteStorageEngine(databaseURL: databaseURL)
            try await storage.createVaultHeader(header)
            try await storage.insertObject(object)
        }

        let reopenedStorage = try SQLiteStorageEngine(databaseURL: databaseURL)

        let storedObject = try await reopenedStorage.loadObject(id: object.id)
        XCTAssertEqual(storedObject, object)
    }

    func testSQLiteListsObjects() async throws {
        let databaseURL = makeDatabaseURL()
        defer { removeDatabaseDirectory(databaseURL) }
        let storage = try SQLiteStorageEngine(databaseURL: databaseURL)
        let header = makeHeader()
        let first = try await makeObject(vaultId: header.vaultId, id: "object-1")
        let second = try await makeObject(vaultId: header.vaultId, id: "object-2")
        try await storage.createVaultHeader(header)
        try await storage.insertObject(first)
        try await storage.insertObject(second)

        let objects = try await storage.listObjects(in: header.vaultId, includeDeleted: false)

        XCTAssertEqual(Set(objects.map(\.id)), Set([first.id, second.id]))
    }

    func testSQLiteExcludesDeletedObjectsByDefault() async throws {
        let databaseURL = makeDatabaseURL()
        defer { removeDatabaseDirectory(databaseURL) }
        let storage = try SQLiteStorageEngine(databaseURL: databaseURL)
        let header = makeHeader()
        let object = try await makeObject(vaultId: header.vaultId)
        try await storage.createVaultHeader(header)
        try await storage.insertObject(object)
        _ = try await storage.markDeleted(id: object.id, at: Date())

        let visibleObjects = try await storage.listObjects(in: header.vaultId, includeDeleted: false)
        let allObjects = try await storage.listObjects(in: header.vaultId, includeDeleted: true)

        XCTAssertTrue(visibleObjects.isEmpty)
        XCTAssertEqual(allObjects.map(\.id), [object.id])
    }

    func testSQLiteRestoresDeletedObject() async throws {
        let databaseURL = makeDatabaseURL()
        defer { removeDatabaseDirectory(databaseURL) }
        let storage = try SQLiteStorageEngine(databaseURL: databaseURL)
        let header = makeHeader()
        let object = try await makeObject(vaultId: header.vaultId)
        try await storage.createVaultHeader(header)
        try await storage.insertObject(object)
        _ = try await storage.markDeleted(id: object.id, at: Date())

        let restored = try await storage.restoreDeleted(id: object.id)

        XCTAssertFalse(restored.isDeleted)
        XCTAssertNil(restored.deletedAt)
        let visibleObjects = try await storage.listObjects(in: header.vaultId, includeDeleted: false)
        XCTAssertEqual(visibleObjects.count, 1)
    }

    func testSQLitePurgesDeletedObject() async throws {
        let databaseURL = makeDatabaseURL()
        defer { removeDatabaseDirectory(databaseURL) }
        let storage = try SQLiteStorageEngine(databaseURL: databaseURL)
        let header = makeHeader()
        let object = try await makeObject(vaultId: header.vaultId)
        let deletedAt = Date(timeIntervalSince1970: 100)
        try await storage.createVaultHeader(header)
        try await storage.insertObject(object)
        _ = try await storage.markDeleted(id: object.id, at: deletedAt)

        let purged = try await storage.purgeDeleted(
            in: header.vaultId,
            olderThan: deletedAt.addingTimeInterval(1)
        )

        XCTAssertEqual(purged.map(\.id), [object.id])
        await XCTAssertThrowsVaultError(.objectNotFound(object.id)) {
            _ = try await storage.loadObject(id: object.id)
        }
    }

    func testSQLiteDoesNotStorePlaintextTitle() async throws {
        let databaseURL = makeDatabaseURL()
        defer { removeDatabaseDirectory(databaseURL) }
        let storage = try SQLiteStorageEngine(databaseURL: databaseURL)
        let header = makeHeader()
        let object = try await makeObject(vaultId: header.vaultId, title: "My Passport")
        try await storage.createVaultHeader(header)
        try await storage.insertObject(object)

        let databaseData = try Data(contentsOf: databaseURL)

        XCTAssertNil(databaseData.range(of: Data("My Passport".utf8)))
    }

    func testSQLiteDoesNotStorePlaintextPayload() async throws {
        let databaseURL = makeDatabaseURL()
        defer { removeDatabaseDirectory(databaseURL) }
        let storage = try SQLiteStorageEngine(databaseURL: databaseURL)
        let header = makeHeader()
        let object = try await makeObject(
            vaultId: header.vaultId,
            payloadSecret: "Passport Number P1234567"
        )
        try await storage.createVaultHeader(header)
        try await storage.insertObject(object)

        let databaseData = try Data(contentsOf: databaseURL)

        XCTAssertNil(databaseData.range(of: Data("Passport Number P1234567".utf8)))
        XCTAssertNil(databaseData.range(of: Data("P1234567".utf8)))
    }

    func testSQLitePersistsEvents() async throws {
        let databaseURL = makeDatabaseURL()
        defer { removeDatabaseDirectory(databaseURL) }
        let storage = try SQLiteStorageEngine(databaseURL: databaseURL)
        let header = makeHeader()
        let event = VaultEvent.objectCreated(
            vaultId: header.vaultId,
            objectId: VaultObjectID("object-1"),
            occurredAt: Date(timeIntervalSince1970: 500)
        )
        try await storage.createVaultHeader(header)

        try await storage.appendEvent(event)

        let events = try await storage.listPersistedEvents(for: header.vaultId)
        XCTAssertEqual(events, [event])
    }

    func testSQLitePersistsBlobRecords() async throws {
        let databaseURL = makeDatabaseURL()
        defer { removeDatabaseDirectory(databaseURL) }
        let storage = try SQLiteStorageEngine(databaseURL: databaseURL)
        let envelope = EncryptedEnvelope(
            version: 1,
            algorithm: .aesGCM,
            keyId: "blob-key-v1",
            nonce: Data([1, 2, 3]),
            ciphertext: Data([4, 5, 6])
        )
        let wrappedKey = WrappedKey(
            keyId: "blob-key-v1",
            wrappingKeyId: "vault-key-v1",
            wrappedData: Data([7, 8, 9]),
            algorithm: .aesGCM
        )
        let record = BlobRecord(
            id: BlobID("blob-1"),
            role: .original,
            contentType: "application/pdf",
            byteCount: 42,
            storagePath: "blobs/bl/blob-1.blob",
            encryptionMetadata: .encryptedBlob(
                EncryptedBlobResult(
                    blobId: BlobID("blob-1"),
                    envelope: envelope,
                    originalSizeBytes: 42,
                    encryptedSizeBytes: 64,
                    checksum: "checksum",
                    createdAt: Date(timeIntervalSince1970: 600)
                )
            ),
            encryptedEnvelope: envelope,
            wrappedKey: wrappedKey,
            createdAt: Date(timeIntervalSince1970: 600)
        )

        try await storage.upsertBlobRecord(record)

        let records = try await storage.listPersistedBlobRecords()
        XCTAssertEqual(records, [record])
    }

    func testSQLiteMigrationIsIdempotent() async throws {
        let databaseURL = makeDatabaseURL()
        defer { removeDatabaseDirectory(databaseURL) }
        _ = try SQLiteStorageEngine(databaseURL: databaseURL)

        let reopened = try SQLiteStorageEngine(databaseURL: databaseURL)

        let migrations = try await reopened.migrationIdentifiers()
        XCTAssertEqual(migrations, ["v1", "v2"])
        XCTAssertEqual(migrations.filter { $0 == "v1" }.count, 1)
        XCTAssertEqual(migrations.filter { $0 == "v2" }.count, 1)
    }

    func testSQLiteUnsupportedSchemaVersionFailsExplicitly() throws {
        let databaseURL = makeDatabaseURL()
        defer { removeDatabaseDirectory(databaseURL) }
        try createDirectory(for: databaseURL)
        try executeSQL(
            """
            CREATE TABLE schema_migrations (
                identifier TEXT PRIMARY KEY NOT NULL,
                applied_at REAL NOT NULL
            );
            INSERT INTO schema_migrations (identifier, applied_at) VALUES ('v99', 1);
            """,
            databaseURL: databaseURL
        )

        XCTAssertThrowsError(try SQLiteStorageEngine(databaseURL: databaseURL)) { error in
            XCTAssertEqual(error as? SQLiteStorageError, .unsupportedSchemaVersion("v99"))
        }
    }

    func testSQLiteCorruptedDatabaseFailsSafely() throws {
        let databaseURL = makeDatabaseURL()
        defer { removeDatabaseDirectory(databaseURL) }
        try createDirectory(for: databaseURL)
        try Data("not a sqlite database".utf8).write(to: databaseURL)

        XCTAssertThrowsError(try SQLiteStorageEngine(databaseURL: databaseURL)) { error in
            XCTAssertNotNil(error as? SQLiteStorageError)
        }
        let bytes = try Data(contentsOf: databaseURL)
        XCTAssertNotNil(bytes.range(of: Data("not a sqlite database".utf8)))
    }

    func testSQLiteMissingRequiredTableFailsWithoutResettingVault() async throws {
        let databaseURL = makeDatabaseURL()
        defer { removeDatabaseDirectory(databaseURL) }
        try createDirectory(for: databaseURL)
        try executeSQL(
            """
            CREATE TABLE schema_migrations (
                identifier TEXT PRIMARY KEY NOT NULL,
                applied_at REAL NOT NULL
            );
            INSERT INTO schema_migrations (identifier, applied_at) VALUES ('v1', 1);
            """,
            databaseURL: databaseURL
        )
        let storage = try SQLiteStorageEngine(databaseURL: databaseURL)

        do {
            _ = try await storage.vaultExists()
            XCTFail("Expected missing vault_headers table to fail.")
        } catch {
            XCTAssertNotNil(error as? SQLiteStorageError)
        }
    }

    func testSQLiteMigrationFailureDoesNotPartiallyApply() throws {
        let databaseURL = makeDatabaseURL()
        defer { removeDatabaseDirectory(databaseURL) }
        try createDirectory(for: databaseURL)
        try executeSQL(
            """
            CREATE TABLE schema_migrations (
                identifier TEXT PRIMARY KEY NOT NULL,
                applied_at REAL NOT NULL
            );
            CREATE TABLE vault_headers (
                incompatible_column TEXT NOT NULL
            );
            """,
            databaseURL: databaseURL
        )

        XCTAssertThrowsError(try SQLiteStorageEngine(databaseURL: databaseURL))

        let migrations = try migrationRows(databaseURL: databaseURL)
        XCTAssertFalse(migrations.contains("v1"))
    }

    func testSQLitePersistsTrustedDevices() async throws {
        let databaseURL = makeDatabaseURL()
        defer { removeDatabaseDirectory(databaseURL) }
        let storage = try SQLiteStorageEngine(databaseURL: databaseURL)
        let header = makeHeader()
        let device = DeviceIdentity(
            deviceId: DeviceID("device-1"),
            deviceName: "Primary iPhone",
            platform: "iOS",
            publicKey: "public-key-placeholder",
            createdAt: Date(timeIntervalSince1970: 650),
            trustState: .trusted,
            permissions: [.read, .write, .manageDevices]
        )
        try await storage.createVaultHeader(header)

        try await storage.upsertTrustedDevice(device, vaultId: header.vaultId)

        let devices = try await storage.listPersistedDevices(for: header.vaultId)
        XCTAssertEqual(devices, [device])
    }

    func testSQLiteObjectMutationPersistsAttachmentsAndEventAtomically() async throws {
        let databaseURL = makeDatabaseURL()
        defer { removeDatabaseDirectory(databaseURL) }
        let storage = try SQLiteStorageEngine(databaseURL: databaseURL)
        let header = makeHeader()
        let object = try await makeObject(vaultId: header.vaultId)
        let attachment = VaultAttachment(
            id: BlobID("blob-1"),
            role: .primary,
            fileName: "must-not-be-persisted.pdf",
            contentType: "application/pdf",
            byteCount: 42
        )
        let event = VaultEvent.attachmentAdded(
            vaultId: header.vaultId,
            objectId: object.id,
            blobId: attachment.id,
            occurredAt: Date(timeIntervalSince1970: 700)
        )
        try await storage.createVaultHeader(header)

        try await storage.persistObjectMutation(
            object,
            attachmentReferences: [attachment],
            event: event
        )

        let references = try await storage.listAttachmentReferences(for: object.id)
        XCTAssertEqual(
            references,
            [VaultAttachmentReferenceRecord(objectId: object.id, blobId: attachment.id, role: .primary)]
        )
        let events = try await storage.listPersistedEvents(for: header.vaultId)
        XCTAssertEqual(events, [event])
        let databaseData = try Data(contentsOf: databaseURL)
        XCTAssertNil(databaseData.range(of: Data("must-not-be-persisted.pdf".utf8)))
    }

    func testSQLiteObjectMutationRollsBackOnAttachmentFailure() async throws {
        let databaseURL = makeDatabaseURL()
        defer { removeDatabaseDirectory(databaseURL) }
        let storage = try SQLiteStorageEngine(databaseURL: databaseURL)
        let header = makeHeader()
        let object = try await makeObject(vaultId: header.vaultId)
        let attachment = VaultAttachment(
            id: BlobID("duplicate-blob"),
            role: .primary,
            fileName: "private.pdf",
            contentType: "application/pdf",
            byteCount: 42
        )
        let event = VaultEvent.objectCreated(vaultId: header.vaultId, objectId: object.id)
        try await storage.createVaultHeader(header)

        do {
            try await storage.persistObjectMutation(
                object,
                attachmentReferences: [attachment, attachment],
                event: event
            )
            XCTFail("Expected duplicate attachment persistence to fail.")
        } catch {
            // The constraint failure is the trigger; state assertions below verify rollback.
        }

        await XCTAssertThrowsVaultError(.objectNotFound(object.id)) {
            _ = try await storage.loadObject(id: object.id)
        }
        let events = try await storage.listPersistedEvents(for: header.vaultId)
        XCTAssertTrue(events.isEmpty)
    }

    private func makeDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("SecureVaultKit-SQLiteTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("vault.sqlite")
    }

    private func removeDatabaseDirectory(_ databaseURL: URL) {
        try? FileManager.default.removeItem(at: databaseURL.deletingLastPathComponent())
    }

    private func createDirectory(for databaseURL: URL) throws {
        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }

    private func executeSQL(_ sql: String, databaseURL: URL) throws {
        var database: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE, nil), SQLITE_OK)
        defer { sqlite3_close(database) }
        let result = sqlite3_exec(database, sql, nil, nil, nil)
        XCTAssertEqual(result, SQLITE_OK)
    }

    private func migrationRows(databaseURL: URL) throws -> [String] {
        var database: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil), SQLITE_OK)
        defer { sqlite3_close(database) }
        var statement: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(database, "SELECT identifier FROM schema_migrations", -1, &statement, nil), SQLITE_OK)
        defer { sqlite3_finalize(statement) }
        var identifiers: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let text = sqlite3_column_text(statement, 0) {
                identifiers.append(String(cString: text))
            }
        }
        return identifiers
    }

    private func makeHeader(vaultId: VaultID = VaultID("vault-1")) -> VaultHeaderRecord {
        VaultHeaderRecord(
            vaultId: vaultId,
            name: "Primary",
            primaryDeviceId: DeviceID("device-1"),
            rootKey: WrappedKey(
                keyId: "root-key-v1",
                wrappingKeyId: "device-key-v1",
                wrappedData: Data([1, 2, 3]),
                algorithm: .aesGCM
            ),
            vaultEncryptionKey: WrappedKey(
                keyId: "vault-key-v1",
                wrappingKeyId: "root-key-v1",
                wrappedData: Data([4, 5, 6]),
                algorithm: .aesGCM
            ),
            createdAt: Date(timeIntervalSince1970: 100)
        )
    }

    private func makeObject(
        vaultId: VaultID,
        id: VaultObjectID = VaultObjectID("object-1"),
        title: String = "Encrypted title",
        payloadSecret: String = "Encrypted payload"
    ) async throws -> VaultObjectRecord {
        let crypto = RealCryptoEngine()
        let itemKey = try await crypto.generateKey()
        let wrappingKey = try await crypto.generateKey()
        let metadata = try JSONEncoder().encode(VaultMetadata(title: title))
        let payload = try JSONEncoder().encode(
            VaultPayload(fields: ["note": .secureText(payloadSecret)])
        )
        return VaultObjectRecord(
            id: id,
            vaultId: vaultId,
            type: .document,
            encryptedMetadata: try await crypto.encrypt(metadata, using: itemKey),
            encryptedPayload: try await crypto.encrypt(payload, using: itemKey),
            wrappedItemKey: try await crypto.wrapKey(itemKey, using: wrappingKey),
            version: 3,
            createdAt: Date(timeIntervalSince1970: 200),
            updatedAt: Date(timeIntervalSince1970: 300)
        )
    }
}
