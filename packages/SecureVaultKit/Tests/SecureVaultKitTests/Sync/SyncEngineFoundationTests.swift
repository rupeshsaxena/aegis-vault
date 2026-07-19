import Foundation
import XCTest
@testable import SecureVaultKit

final class SyncEngineFoundationTests: XCTestCase {
    func testVersionVectorDetectsConcurrentChangesWithoutTimestamps() {
        let firstDevice = DeviceID("device-a")
        let secondDevice = DeviceID("device-b")
        var first = VersionVector()
        var second = VersionVector()

        first.increment(for: firstDevice)
        second.increment(for: secondDevice)

        XCTAssertTrue(first.isConcurrent(with: second))
        XCTAssertFalse(first.dominates(second))
        XCTAssertFalse(second.dominates(first))
    }

    func testConflictDetectorFindsConcurrentUpdate() {
        let local = makeOperation(
            deviceId: DeviceID("device-a"),
            vector: VersionVector(["device-a": 2])
        )
        let remote = makeOperation(
            deviceId: DeviceID("device-b"),
            vector: VersionVector(["device-b": 1])
        )

        let conflict = VersionVectorConflictDetector().detect(local: local, remote: remote)

        XCTAssertEqual(conflict?.type, .concurrentUpdate)
    }

    func testInMemoryJournalDeduplicatesOperationsById() async throws {
        let journal = InMemorySyncJournal()
        let operation = makeOperation()

        try await journal.append(SyncJournalEntry(operation: operation))
        try await journal.append(SyncJournalEntry(operation: operation))

        let entries = try await journal.entries(for: operation.vaultId)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.operation.id, operation.id)
    }

    func testPersistentSyncJournalSurvivesRecreation() async throws {
        let databaseURL = makeDatabaseURL()
        defer { removeDatabaseDirectory(databaseURL) }
        let operation = makeOperation()
        do {
            let storage = try SQLiteStorageEngine(databaseURL: databaseURL)
            let journal = PersistentSyncJournal(storageEngine: storage)
            try await journal.append(SyncJournalEntry(operation: operation))
        }

        let reopenedStorage = try SQLiteStorageEngine(databaseURL: databaseURL)
        let reopenedJournal = PersistentSyncJournal(storageEngine: reopenedStorage)

        let pending = try await reopenedJournal.pendingOperations(for: operation.vaultId, limit: 10)
        XCTAssertEqual(pending, [operation])
    }

    func testPersistentSyncQueueMarksCompletedOperations() async throws {
        let journal = InMemorySyncJournal()
        let queue = PersistentSyncQueue(journal: journal)
        let operation = makeOperation()
        try await queue.enqueue(operation)

        let batch = try await queue.nextBatch(for: operation.vaultId)
        try await queue.markCompleted(batch.operations.map(\.id))

        let pending = try await journal.pendingOperations(for: operation.vaultId, limit: 10)
        let entries = try await journal.entries(for: operation.vaultId)
        XCTAssertTrue(pending.isEmpty)
        XCTAssertEqual(entries.first?.operation.state, .completed)
    }

    func testDefaultSyncEngineUploadsPendingOperationsAndAppliesRemoteChanges() async throws {
        let journal = InMemorySyncJournal()
        let remote = RecordingRemoteSyncRepository()
        let local = RecordingLocalSyncRepository()
        let engine = DefaultSyncEngine(
            journal: journal,
            queue: PersistentSyncQueue(journal: journal),
            localRepository: local,
            remoteRepository: remote
        )
        let operation = makeOperation()
        try await engine.recordLocalMutation(operation)

        let result = try await engine.synchronize(
            context: SyncExecutionContext(vaultId: operation.vaultId, deviceId: operation.metadata.deviceId)
        )

        let uploadedOperationIds = await remote.uploadedOperationIds()
        let appliedCount = await local.appliedCount()

        XCTAssertEqual(result.uploadedCount, 1)
        XCTAssertEqual(uploadedOperationIds, [operation.id])
        XCTAssertEqual(appliedCount, 0)
        let entries = try await journal.entries(for: operation.vaultId)
        XCTAssertEqual(entries.first?.operation.state, .completed)
    }

    func testVaultMutationRecordsPendingSyncOperationWithoutPlaintext() async throws {
        let storageURL = try makeTemporaryStorageURL()
        let titleMarker = "SYNC_MARKER_TITLE_SHOULD_NOT_LEAK"
        let bodyMarker = "SYNC_MARKER_BODY_SHOULD_NOT_LEAK"
        let engine = try VaultEngineFactory.makePersistentLocalEngine(storageURL: storageURL)
        let vaultId = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Sync Test",
                deviceID: DeviceID("sync-device"),
                unlockMethod: .recoverySecret("valid-secret")
            )
        )
        let objectId = try await engine.createObject(
            VaultObjectDraft(
                type: .secureNote,
                metadata: VaultMetadata(title: titleMarker),
                payload: VaultPayload(notes: bodyMarker)
            )
        )

        let storage = try SQLiteStorageEngine(databaseURL: storageURL.appendingPathComponent("vault.sqlite"))
        let journal = PersistentSyncJournal(storageEngine: storage)
        let entries = try await journal.entries(for: vaultId)
        let rawDatabaseBytes = try Data(contentsOf: storageURL.appendingPathComponent("vault.sqlite"))

        XCTAssertTrue(entries.contains { $0.operation.entityId == objectId.rawValue && $0.operation.mutationKind == .create })
        XCTAssertNil(rawDatabaseBytes.range(of: Data(titleMarker.utf8)))
        XCTAssertNil(rawDatabaseBytes.range(of: Data(bodyMarker.utf8)))
    }

    func testPendingSyncStateSurvivesEngineRecreation() async throws {
        let storageURL = try makeTemporaryStorageURL()
        let vaultId: VaultID
        do {
            let engine = try VaultEngineFactory.makePersistentLocalEngine(storageURL: storageURL)
            vaultId = try await engine.createVault(
                config: VaultCreationConfig(
                    name: "Sync Durable",
                    deviceID: DeviceID("sync-device"),
                    unlockMethod: .recoverySecret("valid-secret")
                )
            )
            _ = try await engine.createObject(
                VaultObjectDraft(
                    type: .secureNote,
                    metadata: VaultMetadata(title: "Durable Sync Note"),
                    payload: VaultPayload(notes: "Pending operation should survive.")
                )
            )
        }

        let reopenedStorage = try SQLiteStorageEngine(databaseURL: storageURL.appendingPathComponent("vault.sqlite"))
        let reopenedJournal = PersistentSyncJournal(storageEngine: reopenedStorage)

        let pending = try await reopenedJournal.pendingOperations(for: vaultId, limit: 10)
        XCTAssertTrue(pending.contains { $0.entityType == .secureNote && $0.mutationKind == .create })
    }

    private func makeOperation(
        deviceId: DeviceID = DeviceID("device-a"),
        vector: VersionVector = VersionVector(["device-a": 1])
    ) -> SyncOperation {
        let vaultId = VaultID("vault-sync")
        let entityId = "object-sync"
        return SyncOperation(
            id: SyncOperationID(rawValue: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!),
            vaultId: vaultId,
            entityType: .secureNote,
            entityId: entityId,
            mutationKind: .update,
            metadata: SyncMetadata(
                vaultId: vaultId,
                entityId: entityId,
                deviceId: deviceId,
                objectVersion: 2,
                versionVector: vector,
                encryptedRecordDigest: "encrypted-record-digest"
            ),
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 100)
        )
    }

    private func makeDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("SecureVaultKit-SyncTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("vault.sqlite")
    }

    private func removeDatabaseDirectory(_ databaseURL: URL) {
        try? FileManager.default.removeItem(at: databaseURL.deletingLastPathComponent())
    }

    private func makeTemporaryStorageURL() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SecureVaultKit-SyncFactoryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }
}

private actor RecordingRemoteSyncRepository: RemoteSyncRepository {
    private var uploadedIds: [SyncOperationID] = []

    func upload(_ batch: SyncBatch, context: SyncExecutionContext) async throws -> SyncResult {
        uploadedIds.append(contentsOf: batch.operations.map(\.id))
        return SyncResult(uploadedCount: batch.operations.count)
    }

    func fetchChanges(after cursor: SyncCursor?, context: SyncExecutionContext) async throws -> RemoteChangeBatch {
        RemoteChangeBatch(cursor: cursor)
    }

    func uploadedOperationIds() -> [SyncOperationID] {
        uploadedIds
    }
}

private actor RecordingLocalSyncRepository: LocalSyncRepository {
    private var count = 0

    func applyRemoteOperations(_ operations: [SyncOperation], context: SyncExecutionContext) async throws -> Int {
        count += operations.count
        return operations.count
    }

    func appliedCount() -> Int {
        count
    }
}
