import Foundation
import SQLite3

internal enum SQLiteStorageError: Error, Equatable, Sendable {
    case openFailed(Int32)
    case statementFailed(Int32)
    case invalidStoredRecord
}

internal struct VaultAttachmentReferenceRecord: Equatable, Sendable {
    var objectId: VaultObjectID
    var blobId: BlobID
    var role: AttachmentRole
}

internal actor SQLiteStorageEngine: StorageEngine {
    private static let migrationV1 = "v1"
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private var database: OpaquePointer?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    internal let databaseURL: URL

    internal init(databaseURL: URL) throws {
        self.databaseURL = databaseURL
        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var openedDatabase: OpaquePointer?
        let result = sqlite3_open_v2(
            databaseURL.path,
            &openedDatabase,
            SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
            nil
        )
        guard result == SQLITE_OK, let openedDatabase else {
            if let openedDatabase {
                sqlite3_close(openedDatabase)
            }
            throw SQLiteStorageError.openFailed(result)
        }
        do {
            try Self.bootstrapDatabase(openedDatabase)
        } catch {
            sqlite3_close(openedDatabase)
            throw error
        }
        database = openedDatabase
    }

    deinit {
        if let database {
            sqlite3_close(database)
        }
    }

    func vaultExists() throws -> Bool {
        try scalarInt("SELECT COUNT(*) FROM vault_headers") > 0
    }

    func createVaultHeader(_ record: VaultHeaderRecord) throws {
        guard try !vaultExists() else {
            throw VaultError.vaultAlreadyExists
        }
        try insertVaultHeader(record, replaceExisting: false)
    }

    func loadVaultHeader() throws -> VaultHeaderRecord {
        try withStatement(
            """
            SELECT vault_id, name, primary_device_id, root_key, vault_encryption_key, created_at
            FROM vault_headers ORDER BY created_at LIMIT 1
            """
        ) { statement in
            guard sqlite3_step(statement) == SQLITE_ROW else {
                throw VaultError.vaultNotFound(VaultID("primary"))
            }
            return try decodeVaultHeader(statement)
        }
    }

    func loadVaultHeader(vaultId: VaultID) throws -> VaultHeaderRecord {
        try readVaultHeader(vaultId: vaultId)
    }

    func readVaultHeader(vaultId: VaultID) throws -> VaultHeaderRecord {
        try withStatement(
            """
            SELECT vault_id, name, primary_device_id, root_key, vault_encryption_key, created_at
            FROM vault_headers WHERE vault_id = ?
            """
        ) { statement in
            try bind(vaultId.rawValue, to: statement, at: 1)
            guard sqlite3_step(statement) == SQLITE_ROW else {
                throw VaultError.vaultNotFound(vaultId)
            }
            return try decodeVaultHeader(statement)
        }
    }

    func writeVaultHeader(_ record: VaultHeaderRecord) throws {
        try insertVaultHeader(record, replaceExisting: true)
    }

    func insertObject(_ record: VaultObjectRecord) throws {
        try insertObjectRow(record, conflictClause: "")
    }

    func updateObject(_ record: VaultObjectRecord) throws {
        try withStatement(
            """
            UPDATE vault_objects SET
                vault_id = ?, object_type = ?, encrypted_metadata = ?, encrypted_payload = ?,
                wrapped_item_key = ?, is_deleted = ?, deleted_at = ?, object_version = ?,
                created_at = ?, updated_at = ?
            WHERE object_id = ?
            """
        ) { statement in
            try bindObject(record, to: statement, startingAt: 1, idLast: true)
            try stepDone(statement)
            guard sqlite3_changes(database) == 1 else {
                throw VaultError.objectNotFound(record.id)
            }
        }
    }

    func loadObject(id: VaultObjectID) throws -> VaultObjectRecord {
        try readObject(id: id)
    }

    func listObjects(in vaultId: VaultID) throws -> [VaultObjectRecord] {
        try listObjects(in: vaultId, includeDeleted: true)
    }

    func listObjects(in vaultId: VaultID, includeDeleted: Bool) throws -> [VaultObjectRecord] {
        let deletedClause = includeDeleted ? "" : " AND is_deleted = 0"
        return try withStatement(
            """
            SELECT object_id, vault_id, object_type, encrypted_metadata, encrypted_payload,
                   wrapped_item_key, is_deleted, deleted_at, object_version, created_at, updated_at
            FROM vault_objects WHERE vault_id = ?\(deletedClause) ORDER BY created_at
            """
        ) { statement in
            try bind(vaultId.rawValue, to: statement, at: 1)
            var records: [VaultObjectRecord] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                records.append(try decodeObject(statement))
            }
            return records
        }
    }

    func markDeleted(id: VaultObjectID, at deletedAt: Date) throws -> VaultObjectRecord {
        try withStatement(
            "UPDATE vault_objects SET is_deleted = 1, deleted_at = ?, updated_at = ? WHERE object_id = ?"
        ) { statement in
            sqlite3_bind_double(statement, 1, deletedAt.timeIntervalSince1970)
            sqlite3_bind_double(statement, 2, deletedAt.timeIntervalSince1970)
            try bind(id.rawValue, to: statement, at: 3)
            try stepDone(statement)
            guard sqlite3_changes(database) == 1 else {
                throw VaultError.objectNotFound(id)
            }
        }
        return try readObject(id: id)
    }

    func restoreDeleted(id: VaultObjectID) throws -> VaultObjectRecord {
        let restoredAt = Date()
        try withStatement(
            "UPDATE vault_objects SET is_deleted = 0, deleted_at = NULL, updated_at = ? WHERE object_id = ?"
        ) { statement in
            sqlite3_bind_double(statement, 1, restoredAt.timeIntervalSince1970)
            try bind(id.rawValue, to: statement, at: 2)
            try stepDone(statement)
            guard sqlite3_changes(database) == 1 else {
                throw VaultError.objectNotFound(id)
            }
        }
        return try readObject(id: id)
    }

    func purgeDeleted(in vaultId: VaultID, olderThan cutoff: Date) throws -> [VaultObjectRecord] {
        try inTransaction {
            let records = try withStatement(
                """
                SELECT object_id, vault_id, object_type, encrypted_metadata, encrypted_payload,
                       wrapped_item_key, is_deleted, deleted_at, object_version, created_at, updated_at
                FROM vault_objects
                WHERE vault_id = ? AND is_deleted = 1 AND deleted_at < ?
                ORDER BY created_at
                """
            ) { statement in
                try bind(vaultId.rawValue, to: statement, at: 1)
                sqlite3_bind_double(statement, 2, cutoff.timeIntervalSince1970)
                var records: [VaultObjectRecord] = []
                while sqlite3_step(statement) == SQLITE_ROW {
                    records.append(try decodeObject(statement))
                }
                return records
            }

            try withStatement(
                "DELETE FROM vault_objects WHERE vault_id = ? AND is_deleted = 1 AND deleted_at < ?"
            ) { statement in
                try bind(vaultId.rawValue, to: statement, at: 1)
                sqlite3_bind_double(statement, 2, cutoff.timeIntervalSince1970)
                try stepDone(statement)
            }
            return records
        }
    }

    func readObject(id: VaultObjectID) throws -> VaultObjectRecord {
        try withStatement(
            """
            SELECT object_id, vault_id, object_type, encrypted_metadata, encrypted_payload,
                   wrapped_item_key, is_deleted, deleted_at, object_version, created_at, updated_at
            FROM vault_objects WHERE object_id = ?
            """
        ) { statement in
            try bind(id.rawValue, to: statement, at: 1)
            guard sqlite3_step(statement) == SQLITE_ROW else {
                throw VaultError.objectNotFound(id)
            }
            return try decodeObject(statement)
        }
    }

    func writeObject(_ record: VaultObjectRecord) throws {
        try insertObjectRow(
            record,
            conflictClause: """
            ON CONFLICT(object_id) DO UPDATE SET
                vault_id = excluded.vault_id,
                object_type = excluded.object_type,
                encrypted_metadata = excluded.encrypted_metadata,
                encrypted_payload = excluded.encrypted_payload,
                wrapped_item_key = excluded.wrapped_item_key,
                is_deleted = excluded.is_deleted,
                deleted_at = excluded.deleted_at,
                object_version = excluded.object_version,
                created_at = excluded.created_at,
                updated_at = excluded.updated_at
            """
        )
    }

    func queryObjects(in vaultId: VaultID, matching filter: VaultObjectFilter) throws -> [VaultObjectRecord] {
        try listObjects(in: vaultId, includeDeleted: filter.includeDeleted)
            .filter { filter.types.isEmpty || filter.types.contains($0.type) }
    }

    func persistObjectMutation(
        _ record: VaultObjectRecord,
        attachmentReferences: [VaultAttachment] = [],
        event: VaultEvent? = nil
    ) throws {
        try inTransaction {
            try insertObjectRow(record, conflictClause: "")
            for attachment in attachmentReferences {
                try insertAttachmentReference(attachment, objectId: record.id)
            }
            if let event {
                try insertEvent(event)
            }
        }
    }

    func listAttachmentReferences(for objectId: VaultObjectID) throws -> [VaultAttachmentReferenceRecord] {
        try withStatement(
            "SELECT object_id, blob_id, role FROM vault_attachments WHERE object_id = ? ORDER BY blob_id"
        ) { statement in
            try bind(objectId.rawValue, to: statement, at: 1)
            var records: [VaultAttachmentReferenceRecord] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let role = AttachmentRole(rawValue: try string(statement, at: 2)) else {
                    throw SQLiteStorageError.invalidStoredRecord
                }
                records.append(
                    VaultAttachmentReferenceRecord(
                        objectId: VaultObjectID(try string(statement, at: 0)),
                        blobId: BlobID(try string(statement, at: 1)),
                        role: role
                    )
                )
            }
            return records
        }
    }

    func appendEvent(_ event: VaultEvent) throws {
        try insertEvent(event)
    }

    func listPersistedEvents(for vaultId: VaultID) throws -> [VaultEvent] {
        try withStatement(
            """
            SELECT vault_id, event_type, object_id, blob_id, device_id, object_version, occurred_at
            FROM vault_events WHERE vault_id = ? ORDER BY event_id
            """
        ) { statement in
            try bind(vaultId.rawValue, to: statement, at: 1)
            var events: [VaultEvent] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let type = VaultEventType(rawValue: try string(statement, at: 1)) else {
                    throw SQLiteStorageError.invalidStoredRecord
                }
                let objectId = optionalString(statement, at: 2).map { VaultObjectID($0) }
                let blobId = optionalString(statement, at: 3).map { BlobID($0) }
                let deviceId = optionalString(statement, at: 4).map { DeviceID($0) }
                let event = VaultEvent(
                    vaultId: VaultID(try string(statement, at: 0)),
                    type: type,
                    objectId: objectId,
                    blobId: blobId,
                    deviceId: deviceId,
                    objectVersion: optionalInt(statement, at: 5),
                    occurredAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 6))
                )
                events.append(event)
            }
            return events
        }
    }

    func upsertTrustedDevice(_ device: DeviceIdentity, vaultId: VaultID) throws {
        let permissions = try encoder.encode(device.permissions)
        try withStatement(
            """
            INSERT INTO trusted_devices (
                vault_id, device_id, device_name, platform, public_key, created_at, trust_state, permissions
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(vault_id, device_id) DO UPDATE SET
                device_name = excluded.device_name,
                platform = excluded.platform,
                public_key = excluded.public_key,
                trust_state = excluded.trust_state,
                permissions = excluded.permissions
            """
        ) { statement in
            try bind(vaultId.rawValue, to: statement, at: 1)
            try bind(device.deviceId.rawValue, to: statement, at: 2)
            try bind(device.deviceName, to: statement, at: 3)
            try bind(device.platform, to: statement, at: 4)
            try bind(device.publicKey, to: statement, at: 5)
            sqlite3_bind_double(statement, 6, device.createdAt.timeIntervalSince1970)
            try bind(device.trustState.rawValue, to: statement, at: 7)
            try bind(permissions, to: statement, at: 8)
            try stepDone(statement)
        }
    }

    func listPersistedDevices(for vaultId: VaultID) throws -> [DeviceIdentity] {
        try withStatement(
            """
            SELECT device_id, device_name, platform, public_key, created_at, trust_state, permissions
            FROM trusted_devices WHERE vault_id = ? ORDER BY created_at
            """
        ) { statement in
            try bind(vaultId.rawValue, to: statement, at: 1)
            var devices: [DeviceIdentity] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let trustState = DeviceTrustState(rawValue: try string(statement, at: 5)) else {
                    throw SQLiteStorageError.invalidStoredRecord
                }
                let permissions = try decoder.decode([DevicePermission].self, from: try data(statement, at: 6))
                devices.append(
                    DeviceIdentity(
                        deviceId: DeviceID(try string(statement, at: 0)),
                        deviceName: try string(statement, at: 1),
                        platform: try string(statement, at: 2),
                        publicKey: try string(statement, at: 3),
                        createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 4)),
                        trustState: trustState,
                        permissions: permissions
                    )
                )
            }
            return devices
        }
    }

    func upsertBlobRecord(_ record: BlobRecord) throws {
        try withStatement(
            """
            INSERT INTO blob_records (
                blob_id, role, content_type, byte_count, storage_path,
                encryption_algorithm, key_reference, is_plaintext_persisted, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(blob_id) DO UPDATE SET
                role = excluded.role,
                content_type = excluded.content_type,
                byte_count = excluded.byte_count,
                storage_path = excluded.storage_path,
                encryption_algorithm = excluded.encryption_algorithm,
                key_reference = excluded.key_reference,
                is_plaintext_persisted = excluded.is_plaintext_persisted
            """
        ) { statement in
            try bind(record.id.rawValue, to: statement, at: 1)
            try bind(record.role.rawValue, to: statement, at: 2)
            try bind(record.contentType, to: statement, at: 3)
            sqlite3_bind_int64(statement, 4, Int64(record.byteCount))
            try bindOptional(record.storagePath, to: statement, at: 5)
            try bind(record.encryptionMetadata.algorithm, to: statement, at: 6)
            try bind(record.encryptionMetadata.keyReference, to: statement, at: 7)
            sqlite3_bind_int(statement, 8, record.encryptionMetadata.isPlaintextPersisted ? 1 : 0)
            sqlite3_bind_double(statement, 9, record.createdAt.timeIntervalSince1970)
            try stepDone(statement)
        }
    }

    func listPersistedBlobRecords() throws -> [BlobRecord] {
        try withStatement(
            """
            SELECT blob_id, role, content_type, byte_count, storage_path,
                   encryption_algorithm, key_reference, is_plaintext_persisted, created_at
            FROM blob_records ORDER BY created_at
            """
        ) { statement in
            var records: [BlobRecord] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let role = BlobRole(rawValue: try string(statement, at: 1)) else {
                    throw SQLiteStorageError.invalidStoredRecord
                }
                records.append(
                    BlobRecord(
                        id: BlobID(try string(statement, at: 0)),
                        role: role,
                        contentType: try string(statement, at: 2),
                        byteCount: Int(sqlite3_column_int64(statement, 3)),
                        storagePath: optionalString(statement, at: 4),
                        encryptionMetadata: BlobEncryptionMetadata(
                            algorithm: try string(statement, at: 5),
                            keyReference: try string(statement, at: 6),
                            isPlaintextPersisted: sqlite3_column_int(statement, 7) != 0
                        ),
                        createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 8))
                    )
                )
            }
            return records
        }
    }

    func migrationIdentifiers() throws -> [String] {
        try withStatement("SELECT identifier FROM schema_migrations ORDER BY identifier") { statement in
            var identifiers: [String] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                identifiers.append(try string(statement, at: 0))
            }
            return identifiers
        }
    }

    func schemaTableNames() throws -> [String] {
        try withStatement(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name"
        ) { statement in
            var names: [String] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                names.append(try string(statement, at: 0))
            }
            return names
        }
    }

    private static func bootstrapDatabase(_ database: OpaquePointer) throws {
        try execute(on: database, sql: "PRAGMA foreign_keys = ON")
        try execute(
            on: database,
            sql:
            """
            CREATE TABLE IF NOT EXISTS schema_migrations (
                identifier TEXT PRIMARY KEY NOT NULL,
                applied_at REAL NOT NULL
            )
            """
        )
        guard try scalarInt(
            on: database,
            sql: "SELECT COUNT(*) FROM schema_migrations WHERE identifier = '\(Self.migrationV1)'"
        ) == 0 else {
            return
        }

        try execute(on: database, sql: "BEGIN IMMEDIATE TRANSACTION")
        do {
            try execute(
                on: database,
                sql:
                """
                CREATE TABLE vault_headers (
                    vault_id TEXT PRIMARY KEY NOT NULL,
                    name TEXT NOT NULL,
                    primary_device_id TEXT NOT NULL,
                    root_key BLOB NOT NULL,
                    vault_encryption_key BLOB NOT NULL,
                    created_at REAL NOT NULL
                )
                """
            )
            try execute(
                on: database,
                sql:
                """
                CREATE TABLE vault_objects (
                    object_id TEXT PRIMARY KEY NOT NULL,
                    vault_id TEXT NOT NULL REFERENCES vault_headers(vault_id) ON DELETE CASCADE,
                    object_type TEXT NOT NULL,
                    encrypted_metadata BLOB NOT NULL,
                    encrypted_payload BLOB NOT NULL,
                    wrapped_item_key BLOB NOT NULL,
                    is_deleted INTEGER NOT NULL DEFAULT 0,
                    deleted_at REAL,
                    object_version INTEGER NOT NULL,
                    created_at REAL NOT NULL,
                    updated_at REAL NOT NULL
                )
                """
            )
            try execute(
                on: database,
                sql: "CREATE INDEX vault_objects_vault_id ON vault_objects(vault_id, is_deleted, created_at)"
            )
            try execute(
                on: database,
                sql:
                """
                CREATE TABLE vault_attachments (
                    object_id TEXT NOT NULL REFERENCES vault_objects(object_id) ON DELETE CASCADE,
                    blob_id TEXT NOT NULL,
                    role TEXT NOT NULL,
                    PRIMARY KEY (object_id, blob_id, role)
                )
                """
            )
            try execute(
                on: database,
                sql:
                """
                CREATE TABLE vault_events (
                    event_id INTEGER PRIMARY KEY AUTOINCREMENT,
                    vault_id TEXT NOT NULL REFERENCES vault_headers(vault_id) ON DELETE CASCADE,
                    event_type TEXT NOT NULL,
                    object_id TEXT,
                    blob_id TEXT,
                    device_id TEXT,
                    object_version INTEGER,
                    occurred_at REAL NOT NULL
                )
                """
            )
            try execute(
                on: database,
                sql:
                """
                CREATE TABLE trusted_devices (
                    vault_id TEXT NOT NULL REFERENCES vault_headers(vault_id) ON DELETE CASCADE,
                    device_id TEXT NOT NULL,
                    device_name TEXT NOT NULL,
                    platform TEXT NOT NULL,
                    public_key TEXT NOT NULL,
                    created_at REAL NOT NULL,
                    trust_state TEXT NOT NULL,
                    permissions BLOB NOT NULL,
                    PRIMARY KEY (vault_id, device_id)
                )
                """
            )
            try execute(
                on: database,
                sql:
                """
                CREATE TABLE blob_records (
                    blob_id TEXT PRIMARY KEY NOT NULL,
                    role TEXT NOT NULL,
                    content_type TEXT NOT NULL,
                    byte_count INTEGER NOT NULL,
                    storage_path TEXT,
                    encryption_algorithm TEXT NOT NULL,
                    key_reference TEXT NOT NULL,
                    is_plaintext_persisted INTEGER NOT NULL,
                    created_at REAL NOT NULL
                )
                """
            )
            let appliedAt = Date().timeIntervalSince1970
            try execute(
                on: database,
                sql: "INSERT INTO schema_migrations (identifier, applied_at) VALUES ('\(Self.migrationV1)', \(appliedAt))"
            )
            try execute(on: database, sql: "COMMIT")
        } catch {
            try? execute(on: database, sql: "ROLLBACK")
            throw error
        }
    }

    private static func execute(on database: OpaquePointer, sql: String) throws {
        let result = sqlite3_exec(database, sql, nil, nil, nil)
        guard result == SQLITE_OK else {
            throw SQLiteStorageError.statementFailed(result)
        }
    }

    private static func scalarInt(on database: OpaquePointer, sql: String) throws -> Int {
        var statement: OpaquePointer?
        let prepareResult = sqlite3_prepare_v2(database, sql, -1, &statement, nil)
        guard prepareResult == SQLITE_OK, let statement else {
            throw SQLiteStorageError.statementFailed(prepareResult)
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw SQLiteStorageError.invalidStoredRecord
        }
        return Int(sqlite3_column_int64(statement, 0))
    }

    private func insertVaultHeader(_ record: VaultHeaderRecord, replaceExisting: Bool) throws {
        let rootKey = try encoder.encode(record.rootKey)
        let vaultEncryptionKey = try encoder.encode(record.vaultEncryptionKey)
        let conflictClause = replaceExisting
            ? "ON CONFLICT(vault_id) DO UPDATE SET name = excluded.name, primary_device_id = excluded.primary_device_id, root_key = excluded.root_key, vault_encryption_key = excluded.vault_encryption_key, created_at = excluded.created_at"
            : ""
        try withStatement(
            """
            INSERT INTO vault_headers (
                vault_id, name, primary_device_id, root_key, vault_encryption_key, created_at
            ) VALUES (?, ?, ?, ?, ?, ?) \(conflictClause)
            """
        ) { statement in
            try bind(record.vaultId.rawValue, to: statement, at: 1)
            try bind(record.name, to: statement, at: 2)
            try bind(record.primaryDeviceId.rawValue, to: statement, at: 3)
            try bind(rootKey, to: statement, at: 4)
            try bind(vaultEncryptionKey, to: statement, at: 5)
            sqlite3_bind_double(statement, 6, record.createdAt.timeIntervalSince1970)
            try stepDone(statement)
        }
    }

    private func decodeVaultHeader(_ statement: OpaquePointer) throws -> VaultHeaderRecord {
        VaultHeaderRecord(
            vaultId: VaultID(try string(statement, at: 0)),
            name: try string(statement, at: 1),
            primaryDeviceId: DeviceID(try string(statement, at: 2)),
            rootKey: try decoder.decode(WrappedKey.self, from: try data(statement, at: 3)),
            vaultEncryptionKey: try decoder.decode(WrappedKey.self, from: try data(statement, at: 4)),
            createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 5))
        )
    }

    private func insertObjectRow(_ record: VaultObjectRecord, conflictClause: String) throws {
        try withStatement(
            """
            INSERT INTO vault_objects (
                object_id, vault_id, object_type, encrypted_metadata, encrypted_payload,
                wrapped_item_key, is_deleted, deleted_at, object_version, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) \(conflictClause)
            """
        ) { statement in
            try bindObject(record, to: statement, startingAt: 1, idLast: false)
            try stepDone(statement)
        }
    }

    private func bindObject(
        _ record: VaultObjectRecord,
        to statement: OpaquePointer,
        startingAt start: Int32,
        idLast: Bool
    ) throws {
        let metadata = try encoder.encode(record.encryptedMetadata)
        let payload = try encoder.encode(record.encryptedPayload)
        let wrappedKey = try encoder.encode(record.wrappedItemKey)
        var index = start

        if !idLast {
            try bind(record.id.rawValue, to: statement, at: index)
            index += 1
        }
        try bind(record.vaultId.rawValue, to: statement, at: index)
        try bind(record.type.rawValue, to: statement, at: index + 1)
        try bind(metadata, to: statement, at: index + 2)
        try bind(payload, to: statement, at: index + 3)
        try bind(wrappedKey, to: statement, at: index + 4)
        sqlite3_bind_int(statement, index + 5, record.isDeleted ? 1 : 0)
        bindOptional(record.deletedAt, to: statement, at: index + 6)
        sqlite3_bind_int64(statement, index + 7, Int64(record.version))
        sqlite3_bind_double(statement, index + 8, record.createdAt.timeIntervalSince1970)
        sqlite3_bind_double(statement, index + 9, record.updatedAt.timeIntervalSince1970)
        if idLast {
            try bind(record.id.rawValue, to: statement, at: index + 10)
        }
    }

    private func decodeObject(_ statement: OpaquePointer) throws -> VaultObjectRecord {
        guard let objectType = VaultObjectType(rawValue: try string(statement, at: 2)) else {
            throw SQLiteStorageError.invalidStoredRecord
        }
        return VaultObjectRecord(
            id: VaultObjectID(try string(statement, at: 0)),
            vaultId: VaultID(try string(statement, at: 1)),
            type: objectType,
            encryptedMetadata: try decoder.decode(EncryptedEnvelope.self, from: try data(statement, at: 3)),
            encryptedPayload: try decoder.decode(EncryptedEnvelope.self, from: try data(statement, at: 4)),
            wrappedItemKey: try decoder.decode(WrappedKey.self, from: try data(statement, at: 5)),
            isDeleted: sqlite3_column_int(statement, 6) != 0,
            deletedAt: optionalDate(statement, at: 7),
            version: Int(sqlite3_column_int64(statement, 8)),
            createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 9)),
            updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 10))
        )
    }

    private func insertAttachmentReference(_ attachment: VaultAttachment, objectId: VaultObjectID) throws {
        try withStatement(
            "INSERT INTO vault_attachments (object_id, blob_id, role) VALUES (?, ?, ?)"
        ) { statement in
            try bind(objectId.rawValue, to: statement, at: 1)
            try bind(attachment.id.rawValue, to: statement, at: 2)
            try bind(attachment.role.rawValue, to: statement, at: 3)
            try stepDone(statement)
        }
    }

    private func insertEvent(_ event: VaultEvent) throws {
        try withStatement(
            """
            INSERT INTO vault_events (
                vault_id, event_type, object_id, blob_id, device_id, object_version, occurred_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            """
        ) { statement in
            try bind(event.vaultId.rawValue, to: statement, at: 1)
            try bind(event.type.rawValue, to: statement, at: 2)
            try bindOptional(event.objectId?.rawValue, to: statement, at: 3)
            try bindOptional(event.blobId?.rawValue, to: statement, at: 4)
            try bindOptional(event.deviceId?.rawValue, to: statement, at: 5)
            if let version = event.objectVersion {
                sqlite3_bind_int64(statement, 6, Int64(version))
            } else {
                sqlite3_bind_null(statement, 6)
            }
            sqlite3_bind_double(statement, 7, event.occurredAt.timeIntervalSince1970)
            try stepDone(statement)
        }
    }

    private func inTransaction<T>(_ updates: () throws -> T) throws -> T {
        try execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            let result = try updates()
            try execute("COMMIT")
            return result
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    private func execute(_ sql: String) throws {
        guard let database else {
            throw SQLiteStorageError.invalidStoredRecord
        }
        let result = sqlite3_exec(database, sql, nil, nil, nil)
        guard result == SQLITE_OK else {
            throw SQLiteStorageError.statementFailed(result)
        }
    }

    private func scalarInt(_ sql: String) throws -> Int {
        try withStatement(sql) { statement in
            guard sqlite3_step(statement) == SQLITE_ROW else {
                throw SQLiteStorageError.invalidStoredRecord
            }
            return Int(sqlite3_column_int64(statement, 0))
        }
    }

    private func withStatement<T>(
        _ sql: String,
        _ operation: (OpaquePointer) throws -> T
    ) throws -> T {
        guard let database else {
            throw SQLiteStorageError.invalidStoredRecord
        }
        var statement: OpaquePointer?
        let result = sqlite3_prepare_v2(database, sql, -1, &statement, nil)
        guard result == SQLITE_OK, let statement else {
            throw SQLiteStorageError.statementFailed(result)
        }
        defer { sqlite3_finalize(statement) }
        return try operation(statement)
    }

    private func stepDone(_ statement: OpaquePointer) throws {
        let result = sqlite3_step(statement)
        guard result == SQLITE_DONE else {
            throw SQLiteStorageError.statementFailed(result)
        }
    }

    private func bind(_ value: String, to statement: OpaquePointer, at index: Int32) throws {
        let result = sqlite3_bind_text(statement, index, value, -1, Self.transient)
        guard result == SQLITE_OK else {
            throw SQLiteStorageError.statementFailed(result)
        }
    }

    private func bindOptional(_ value: String?, to statement: OpaquePointer, at index: Int32) throws {
        guard let value else {
            sqlite3_bind_null(statement, index)
            return
        }
        try bind(value, to: statement, at: index)
    }

    private func bind(_ value: Data, to statement: OpaquePointer, at index: Int32) throws {
        let result = value.withUnsafeBytes { bytes in
            sqlite3_bind_blob(statement, index, bytes.baseAddress, Int32(value.count), Self.transient)
        }
        guard result == SQLITE_OK else {
            throw SQLiteStorageError.statementFailed(result)
        }
    }

    private func bindOptional(_ value: Date?, to statement: OpaquePointer, at index: Int32) {
        if let value {
            sqlite3_bind_double(statement, index, value.timeIntervalSince1970)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }

    private func string(_ statement: OpaquePointer, at index: Int32) throws -> String {
        guard let value = sqlite3_column_text(statement, index) else {
            throw SQLiteStorageError.invalidStoredRecord
        }
        return String(cString: value)
    }

    private func optionalString(_ statement: OpaquePointer, at index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL,
              let value = sqlite3_column_text(statement, index) else {
            return nil
        }
        return String(cString: value)
    }

    private func data(_ statement: OpaquePointer, at index: Int32) throws -> Data {
        let count = Int(sqlite3_column_bytes(statement, index))
        if count == 0 {
            return Data()
        }
        guard let bytes = sqlite3_column_blob(statement, index) else {
            throw SQLiteStorageError.invalidStoredRecord
        }
        return Data(bytes: bytes, count: count)
    }

    private func optionalDate(_ statement: OpaquePointer, at index: Int32) -> Date? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
            return nil
        }
        return Date(timeIntervalSince1970: sqlite3_column_double(statement, index))
    }

    private func optionalInt(_ statement: OpaquePointer, at index: Int32) -> Int? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
            return nil
        }
        return Int(sqlite3_column_int64(statement, index))
    }
}
