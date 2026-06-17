import Foundation
import XCTest
@testable import SecureVaultKit

final class DefaultVaultEngineTests: XCTestCase {
    func testDefaultVaultEngineCanInitialize() {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())

        XCTAssertNotNil(engine)
    }

    func testCreateVaultCreatesUnlockedSession() async throws {
        let configuration = makeInMemoryConfiguration()
        let engine = DefaultVaultEngine(configuration: configuration)
        let deviceId = DeviceID("device-1")

        let vaultId = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: deviceId,
                unlockMethod: .passphrase
            )
        )

        let state = await engine.sessionActor.currentState()
        switch state {
        case .locked:
            XCTFail("Expected createVault to unlock a session.")
        case .unlocked(let session):
            XCTAssertEqual(session.vaultId, vaultId)
            XCTAssertEqual(session.deviceId, deviceId)
            XCTAssertEqual(session.lockState, .unlocked)
            XCTAssertEqual(session.keyReferences.rootVaultKeyReference, "fake-root-vault-key-\(vaultId.rawValue)")
            XCTAssertEqual(session.keyReferences.vaultEncryptionKeyReference, "fake-vault-encryption-key-\(vaultId.rawValue)")
            XCTAssertEqual(session.keyReferences.vaultKeyReference, "fake-vault-encryption-key-\(vaultId.rawValue)")
        }
    }

    func testCreateVaultCreatesVaultHeader() async throws {
        let configuration = makeInMemoryConfiguration()
        let engine = DefaultVaultEngine(configuration: configuration)
        let deviceId = DeviceID("device-1")

        let vaultId = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: deviceId,
                unlockMethod: .passphrase
            )
        )

        let header = try await configuration.storageEngine.loadVaultHeader(vaultId: vaultId)
        XCTAssertEqual(header.vaultId, vaultId)
        XCTAssertEqual(header.name, "Primary")
        XCTAssertEqual(header.primaryDeviceId, deviceId)
        XCTAssertEqual(header.rootKey.keyReference, "fake-root-vault-key-\(vaultId.rawValue)")
        XCTAssertEqual(header.vaultEncryptionKey.keyReference, "fake-vault-encryption-key-\(vaultId.rawValue)")
    }

    func testCreateVaultAppendsVaultCreatedEvent() async throws {
        let configuration = makeInMemoryConfiguration()
        let engine = DefaultVaultEngine(configuration: configuration)

        let vaultId = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )

        let events = try await configuration.eventEngine.listEvents(for: vaultId)
        XCTAssertEqual(events.map(\.type), [.vaultCreated, .deviceRegistered, .deviceTrusted])
        XCTAssertEqual(events.compactMap(\.deviceId), [DeviceID("device-1"), DeviceID("device-1")])
    }

    func testCreateVaultFailsIfVaultAlreadyExists() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        let config = VaultCreationConfig(
            name: "Primary",
            deviceID: DeviceID("device-1"),
            unlockMethod: .passphrase
        )

        _ = try await engine.createVault(config: config)

        await XCTAssertThrowsVaultError(.vaultAlreadyExists) {
            _ = try await engine.createVault(config: config)
        }
    }

    func testLockVaultLocksSession() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        let vaultId = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )

        await engine.lockVault(id: vaultId)

        let state = await engine.sessionActor.currentState()
        XCTAssertEqual(state, .locked)
    }

    func testUnlockVaultFailsIfVaultDoesNotExist() async {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())

        await XCTAssertThrowsVaultError(.vaultNotFound(VaultID("missing"))) {
            try await engine.unlockVault(id: VaultID("missing"), using: .biometric)
        }
    }

    func testUnlockVaultWithEmptyRecoverySecretFails() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        let vaultId = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        await engine.lockVault(id: vaultId)

        await XCTAssertThrowsVaultError(.invalidInput("Recovery secret must not be empty.")) {
            try await engine.unlockVault(id: vaultId, using: .recoverySecret(""))
        }
    }

    func testUnlockVaultWithValidRecoverySecretUnlocksSession() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        let vaultId = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        await engine.lockVault(id: vaultId)

        try await engine.unlockVault(id: vaultId, using: .recoverySecret("valid-secret"))

        let session = try await engine.sessionActor.requireUnlocked()
        XCTAssertEqual(session.vaultId, vaultId)
        XCTAssertEqual(session.lockState, .unlocked)
        XCTAssertEqual(session.keyReferences.vaultKeyReference, "key-\(vaultId.rawValue)-recoverySecret")
    }

    func testBiometricUnlockWorksInFakeMode() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        let vaultId = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        await engine.lockVault(id: vaultId)

        try await engine.unlockVault(id: vaultId, using: .biometric)

        let session = try await engine.sessionActor.requireUnlocked()
        XCTAssertEqual(session.vaultId, vaultId)
        XCTAssertEqual(session.keyReferences.vaultKeyReference, "key-\(vaultId.rawValue)-biometric")
    }

    func testPasskeyUnlockWorksInFakeMode() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        let vaultId = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        await engine.lockVault(id: vaultId)

        try await engine.unlockVault(id: vaultId, using: .passkey)

        let session = try await engine.sessionActor.requireUnlocked()
        XCTAssertEqual(session.vaultId, vaultId)
        XCTAssertEqual(session.keyReferences.vaultKeyReference, "key-\(vaultId.rawValue)-passkey")
    }

    func testLockedVaultRejectsRequireUnlocked() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        let vaultId = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )

        await engine.lockVault(id: vaultId)

        await XCTAssertThrowsVaultError(.locked) {
            _ = try await engine.sessionActor.requireUnlocked()
        }
    }

    func testCreateObjectFailsWhenVaultIsLocked() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        let vaultId = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        await engine.lockVault(id: vaultId)
        let draft = VaultObjectDraft(
            type: .secureNote,
            metadata: VaultMetadata(title: "Note"),
            payload: VaultPayload(fields: ["body": .secureText("secret")])
        )

        await XCTAssertThrowsVaultError(.locked) {
            _ = try await engine.createObject(draft)
        }
    }

    func testCreateObjectFailsWithEmptyTitle() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        _ = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        let draft = VaultObjectDraft(
            type: .secureNote,
            metadata: VaultMetadata(title: "   "),
            payload: VaultPayload(fields: ["body": .secureText("secret")])
        )

        await XCTAssertThrowsVaultError(.invalidInput("Object title must not be empty.")) {
            _ = try await engine.createObject(draft)
        }
    }

    func testCreateObjectStoresObjectRecord() async throws {
        let configuration = makeInMemoryConfiguration()
        let engine = DefaultVaultEngine(configuration: configuration)
        let vaultId = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        let draft = VaultObjectDraft(
            type: .secureNote,
            metadata: VaultMetadata(title: "Launch Note"),
            payload: VaultPayload(fields: ["body": .secureText("secret")])
        )

        let objectId = try await engine.createObject(draft)
        let record = try await configuration.storageEngine.loadObject(id: objectId)

        XCTAssertEqual(record.id, objectId)
        XCTAssertEqual(record.vaultId, vaultId)
        XCTAssertEqual(record.type, .secureNote)
        XCTAssertEqual(record.wrappedItemKey.keyReference, "fake-item-key-\(objectId.rawValue)")
        XCTAssertEqual(record.wrappedItemKey.wrappingKeyReference, "fake-vault-encryption-key-\(vaultId.rawValue)")
    }

    func testCreateObjectAppendsObjectCreatedEvent() async throws {
        let configuration = makeInMemoryConfiguration()
        let engine = DefaultVaultEngine(configuration: configuration)
        let vaultId = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        let draft = VaultObjectDraft(
            type: .secureNote,
            metadata: VaultMetadata(title: "Launch Note"),
            payload: VaultPayload(fields: ["body": .secureText("secret")])
        )

        let objectId = try await engine.createObject(draft)
        let events = try await configuration.eventEngine.listEvents(for: vaultId)

        XCTAssertTrue(events.contains { $0.type == .objectCreated && $0.objectId == objectId })
    }

    func testCreateObjectIndexesSearchableSummary() async throws {
        let configuration = makeInMemoryConfiguration()
        let engine = DefaultVaultEngine(configuration: configuration)
        let vaultId = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        let draft = VaultObjectDraft(
            type: .secureNote,
            metadata: VaultMetadata(title: "Launch Note", tags: ["ops"]),
            payload: VaultPayload(fields: ["body": .secureText("secret")])
        )

        let objectId = try await engine.createObject(draft)
        let summaries = try await configuration.searchEngine.listSummaries(
            in: vaultId,
            matching: VaultObjectFilter(query: "launch")
        )

        XCTAssertEqual(summaries.map(\.id), [objectId])
        XCTAssertEqual(summaries.first?.title, "Launch Note")
        XCTAssertEqual(summaries.first?.tags, ["ops"])
    }

    func testCreateObjectReturnsGeneratedObjectId() async throws {
        let configuration = makeInMemoryConfiguration()
        let engine = DefaultVaultEngine(configuration: configuration)
        _ = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        let draft = VaultObjectDraft(
            type: .secureNote,
            metadata: VaultMetadata(title: "Launch Note"),
            payload: VaultPayload(fields: ["body": .secureText("secret")])
        )

        let objectId = try await engine.createObject(draft)
        let storedObject = try await configuration.storageEngine.loadObject(id: objectId)

        XCTAssertFalse(objectId.rawValue.isEmpty)
        XCTAssertEqual(storedObject.id, objectId)
    }

    func testStoredRecordDoesNotContainPlaintextTitleInEncryptedMetadata() async throws {
        let configuration = makeInMemoryConfiguration()
        let engine = DefaultVaultEngine(configuration: configuration)
        _ = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        let draft = VaultObjectDraft(
            type: .secureNote,
            metadata: VaultMetadata(title: "Plaintext Title"),
            payload: VaultPayload(fields: ["body": .secureText("secret")])
        )

        let objectId = try await engine.createObject(draft)
        let record = try await configuration.storageEngine.loadObject(id: objectId)

        XCTAssertEqual(record.encryptedMetadata.algorithm, .xChaCha20Poly1305)
        XCTAssertFalse(record.encryptedMetadata.ciphertextReference.contains("Plaintext Title"))
        XCTAssertFalse(record.encryptedMetadata.keyReference.contains("Plaintext Title"))
    }

    func testCreateObjectAllowsEmptyPayloadForDocumentPlaceholder() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        _ = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        let draft = VaultObjectDraft(
            type: .document,
            metadata: VaultMetadata(title: "Pending document")
        )

        let objectId = try await engine.createObject(draft)

        XCTAssertFalse(objectId.rawValue.isEmpty)
    }

    func testCreateObjectRejectsEmptyPayloadForSecureNote() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        _ = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        let draft = VaultObjectDraft(
            type: .secureNote,
            metadata: VaultMetadata(title: "Empty note")
        )

        await XCTAssertThrowsVaultError(.invalidInput("Object payload must not be empty.")) {
            _ = try await engine.createObject(draft)
        }
    }

    func testListObjectsFailsWhenLocked() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        let vaultId = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        await engine.lockVault(id: vaultId)

        await XCTAssertThrowsVaultError(.locked) {
            _ = try await engine.listObjects(filter: VaultObjectFilter())
        }
    }

    func testListObjectsReturnsCreatedObjectSummary() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        let vaultId = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        let objectId = try await engine.createObject(
            VaultObjectDraft(
                type: .secureNote,
                metadata: VaultMetadata(title: "Launch Note", subtitle: "Ops", tags: ["ops"]),
                payload: VaultPayload(fields: ["body": .secureText("secret")])
            )
        )

        let summaries = try await engine.listObjects(filter: VaultObjectFilter())

        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(summaries.first?.id, objectId)
        XCTAssertEqual(summaries.first?.vaultId, vaultId)
        XCTAssertEqual(summaries.first?.title, "Launch Note")
        XCTAssertEqual(summaries.first?.subtitle, "Ops")
        XCTAssertEqual(summaries.first?.tags, ["ops"])
        XCTAssertFalse(summaries.first?.isDeleted ?? true)
    }

    func testListObjectsExcludesDeletedObjectsByDefault() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        _ = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        let activeId = try await engine.createObject(
            VaultObjectDraft(
                type: .secureNote,
                metadata: VaultMetadata(title: "Active"),
                payload: VaultPayload(fields: ["body": .secureText("secret")])
            )
        )
        let deletedId = try await engine.createObject(
            VaultObjectDraft(
                type: .secureNote,
                metadata: VaultMetadata(title: "Deleted", deletedAt: Date()),
                payload: VaultPayload(fields: ["body": .secureText("secret")])
            )
        )

        let visible = try await engine.listObjects(filter: VaultObjectFilter())
        let includingDeleted = try await engine.listObjects(filter: VaultObjectFilter(includeDeleted: true))

        XCTAssertEqual(visible.map(\.id), [activeId])
        XCTAssertEqual(Set(includingDeleted.map(\.id)), [activeId, deletedId])
    }

    func testGetObjectDetailFailsWhenLocked() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        let vaultId = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        let objectId = try await engine.createObject(
            VaultObjectDraft(
                type: .secureNote,
                metadata: VaultMetadata(title: "Launch Note"),
                payload: VaultPayload(fields: ["body": .secureText("secret")])
            )
        )
        await engine.lockVault(id: vaultId)

        await XCTAssertThrowsVaultError(.locked) {
            _ = try await engine.getObjectDetail(id: objectId)
        }
    }

    func testGetObjectDetailReturnsMetadataAndPayload() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        _ = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        let objectId = try await engine.createObject(
            VaultObjectDraft(
                type: .secureNote,
                metadata: VaultMetadata(title: "Launch Note", subtitle: "Ops", tags: ["ops"]),
                payload: VaultPayload(fields: ["body": .secureText("secret")])
            )
        )

        let detail = try await engine.getObjectDetail(id: objectId)

        XCTAssertEqual(detail.id, objectId)
        XCTAssertEqual(detail.type, .secureNote)
        XCTAssertEqual(detail.metadata.title, "Launch Note")
        XCTAssertEqual(detail.metadata.subtitle, "Ops")
        XCTAssertEqual(detail.metadata.tags, ["ops"])
        XCTAssertEqual(detail.payload.fields["body"], .secureText("secret"))
        XCTAssertTrue(detail.payload.attachments.isEmpty)
    }

    func testGetObjectDetailFailsForUnknownObjectId() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        _ = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        let objectId = VaultObjectID("missing")

        await XCTAssertThrowsVaultError(.objectNotFound(objectId)) {
            _ = try await engine.getObjectDetail(id: objectId)
        }
    }

    func testMoveToTrashFailsWhenLocked() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        let vaultId = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        let objectId = try await engine.createObject(
            VaultObjectDraft(
                type: .secureNote,
                metadata: VaultMetadata(title: "Trash me"),
                payload: VaultPayload(fields: ["body": .secureText("secret")])
            )
        )
        await engine.lockVault(id: vaultId)

        await XCTAssertThrowsVaultError(.locked) {
            try await engine.moveToTrash(objectId)
        }
    }

    func testMoveToTrashMarksObjectDeleted() async throws {
        let configuration = makeInMemoryConfiguration()
        let engine = DefaultVaultEngine(configuration: configuration)
        _ = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        let objectId = try await engine.createObject(
            VaultObjectDraft(
                type: .secureNote,
                metadata: VaultMetadata(title: "Trash me"),
                payload: VaultPayload(fields: ["body": .secureText("secret")])
            )
        )

        try await engine.moveToTrash(objectId)

        let record = try await configuration.storageEngine.loadObject(id: objectId)
        XCTAssertTrue(record.isDeleted)
        XCTAssertNotNil(record.deletedAt)
        let detail = try await engine.getObjectDetail(id: objectId)
        XCTAssertNotNil(detail.metadata.deletedAt)
    }

    func testMoveToTrashAppendsObjectDeletedEvent() async throws {
        let configuration = makeInMemoryConfiguration()
        let engine = DefaultVaultEngine(configuration: configuration)
        let vaultId = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        let objectId = try await engine.createObject(
            VaultObjectDraft(
                type: .secureNote,
                metadata: VaultMetadata(title: "Trash me"),
                payload: VaultPayload(fields: ["body": .secureText("secret")])
            )
        )

        try await engine.moveToTrash(objectId)

        let events = try await configuration.eventEngine.listEvents(for: vaultId)
        XCTAssertTrue(events.contains { $0.type == .objectDeleted && $0.objectId == objectId })
    }

    func testListObjectsExcludesTrashedObjectByDefault() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        _ = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        let objectId = try await engine.createObject(
            VaultObjectDraft(
                type: .secureNote,
                metadata: VaultMetadata(title: "Trash me"),
                payload: VaultPayload(fields: ["body": .secureText("secret")])
            )
        )

        try await engine.moveToTrash(objectId)

        let summaries = try await engine.listObjects(filter: VaultObjectFilter())
        XCTAssertFalse(summaries.map(\.id).contains(objectId))
    }

    func testListObjectsIncludeDeletedReturnsTrashedObject() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        _ = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        let objectId = try await engine.createObject(
            VaultObjectDraft(
                type: .secureNote,
                metadata: VaultMetadata(title: "Trash me"),
                payload: VaultPayload(fields: ["body": .secureText("secret")])
            )
        )

        try await engine.moveToTrash(objectId)

        let summaries = try await engine.listObjects(filter: VaultObjectFilter(includeDeleted: true))
        XCTAssertEqual(summaries.map(\.id), [objectId])
        XCTAssertTrue(summaries.first?.isDeleted ?? false)
    }

    func testRestoreFromTrashRestoresObject() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        _ = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        let objectId = try await engine.createObject(
            VaultObjectDraft(
                type: .secureNote,
                metadata: VaultMetadata(title: "Restore me"),
                payload: VaultPayload(fields: ["body": .secureText("secret")])
            )
        )
        try await engine.moveToTrash(objectId)

        try await engine.restoreFromTrash(objectId)

        let summaries = try await engine.listObjects(filter: VaultObjectFilter())
        XCTAssertEqual(summaries.map(\.id), [objectId])
        XCTAssertFalse(summaries.first?.isDeleted ?? true)
        let detail = try await engine.getObjectDetail(id: objectId)
        XCTAssertNil(detail.metadata.deletedAt)
    }

    func testRestoreFromTrashAppendsObjectRestoredEvent() async throws {
        let configuration = makeInMemoryConfiguration()
        let engine = DefaultVaultEngine(configuration: configuration)
        let vaultId = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        let objectId = try await engine.createObject(
            VaultObjectDraft(
                type: .secureNote,
                metadata: VaultMetadata(title: "Restore me"),
                payload: VaultPayload(fields: ["body": .secureText("secret")])
            )
        )
        try await engine.moveToTrash(objectId)

        try await engine.restoreFromTrash(objectId)

        let events = try await configuration.eventEngine.listEvents(for: vaultId)
        XCTAssertTrue(events.contains { $0.type == .objectRestored && $0.objectId == objectId })
    }

    func testPurgeTrashRemovesExpiredDeletedObjects() async throws {
        let configuration = makeInMemoryConfiguration()
        let engine = DefaultVaultEngine(configuration: configuration)
        let vaultId = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        let objectId = try await engine.createObject(
            VaultObjectDraft(
                type: .secureNote,
                metadata: VaultMetadata(title: "Purge me"),
                payload: VaultPayload(fields: ["body": .secureText("secret")])
            )
        )
        try await engine.moveToTrash(objectId)
        _ = try await configuration.storageEngine.markDeleted(
            id: objectId,
            at: Date().addingTimeInterval(-31 * 24 * 60 * 60)
        )

        try await engine.purgeTrash()

        await XCTAssertThrowsVaultError(.objectNotFound(objectId)) {
            _ = try await configuration.storageEngine.loadObject(id: objectId)
        }
        let remainingObjects = try await configuration.storageEngine.listObjects(in: vaultId, includeDeleted: true)
        XCTAssertTrue(remainingObjects.isEmpty)
    }

    func testPurgeTrashAppendsObjectPurgedEvent() async throws {
        let configuration = makeInMemoryConfiguration()
        let engine = DefaultVaultEngine(configuration: configuration)
        let vaultId = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        let objectId = try await engine.createObject(
            VaultObjectDraft(
                type: .secureNote,
                metadata: VaultMetadata(title: "Purge me"),
                payload: VaultPayload(fields: ["body": .secureText("secret")])
            )
        )
        try await engine.moveToTrash(objectId)
        _ = try await configuration.storageEngine.markDeleted(
            id: objectId,
            at: Date().addingTimeInterval(-31 * 24 * 60 * 60)
        )

        try await engine.purgeTrash()

        let events = try await configuration.eventEngine.listEvents(for: vaultId)
        XCTAssertTrue(events.contains { $0.type == .objectPurged && $0.objectId == objectId })
    }

    func testUpdateObjectFailsWhenLocked() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        let vaultId = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        let objectId = try await engine.createObject(
            VaultObjectDraft(
                type: .secureNote,
                metadata: VaultMetadata(title: "Original"),
                payload: VaultPayload(fields: ["body": .secureText("one")])
            )
        )
        await engine.lockVault(id: vaultId)

        await XCTAssertThrowsVaultError(.locked) {
            _ = try await engine.updateObject(
                VaultObjectUpdate(objectId: objectId, metadata: VaultMetadata(title: "Updated"))
            )
        }
    }

    func testUpdateObjectFailsForUnknownObject() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        _ = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        let objectId = VaultObjectID("missing")

        await XCTAssertThrowsVaultError(.objectNotFound(objectId)) {
            _ = try await engine.updateObject(
                VaultObjectUpdate(objectId: objectId, metadata: VaultMetadata(title: "Updated"))
            )
        }
    }

    func testUpdateObjectFailsForDeletedObject() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        _ = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        let objectId = try await engine.createObject(
            VaultObjectDraft(
                type: .secureNote,
                metadata: VaultMetadata(title: "Original"),
                payload: VaultPayload(fields: ["body": .secureText("one")])
            )
        )
        try await engine.moveToTrash(objectId)

        await XCTAssertThrowsVaultError(.invalidInput("Cannot update a deleted object.")) {
            _ = try await engine.updateObject(
                VaultObjectUpdate(objectId: objectId, metadata: VaultMetadata(title: "Updated"))
            )
        }
    }

    func testUpdateObjectIncrementsVersion() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        _ = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        let objectId = try await engine.createObject(
            VaultObjectDraft(
                type: .secureNote,
                metadata: VaultMetadata(title: "Original"),
                payload: VaultPayload(fields: ["body": .secureText("one")])
            )
        )

        let updated = try await engine.updateObject(
            VaultObjectUpdate(objectId: objectId, metadata: VaultMetadata(title: "Updated"))
        )

        XCTAssertEqual(updated.version, 2)
        let detail = try await engine.getObjectDetail(id: objectId)
        XCTAssertEqual(detail.version, 2)
    }

    func testUpdateObjectUpdatesMetadataVisibleInListObjects() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        _ = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        let objectId = try await engine.createObject(
            VaultObjectDraft(
                type: .secureNote,
                metadata: VaultMetadata(title: "Original", tags: ["old"]),
                payload: VaultPayload(fields: ["body": .secureText("one")])
            )
        )

        _ = try await engine.updateObject(
            VaultObjectUpdate(objectId: objectId, metadata: VaultMetadata(title: "Updated", tags: ["new"]))
        )
        let summaries = try await engine.listObjects(filter: VaultObjectFilter())

        XCTAssertEqual(summaries.first?.id, objectId)
        XCTAssertEqual(summaries.first?.title, "Updated")
        XCTAssertEqual(summaries.first?.tags, ["new"])
        XCTAssertEqual(summaries.first?.version, 2)
    }

    func testUpdateObjectUpdatesPayloadVisibleInGetObjectDetail() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        _ = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        let objectId = try await engine.createObject(
            VaultObjectDraft(
                type: .secureNote,
                metadata: VaultMetadata(title: "Original"),
                payload: VaultPayload(fields: ["body": .secureText("one")])
            )
        )

        _ = try await engine.updateObject(
            VaultObjectUpdate(
                objectId: objectId,
                payload: VaultPayload(fields: ["body": .secureText("two")])
            )
        )
        let detail = try await engine.getObjectDetail(id: objectId)

        XCTAssertEqual(detail.metadata.title, "Original")
        XCTAssertEqual(detail.payload.fields["body"], .secureText("two"))
        XCTAssertEqual(detail.version, 2)
    }

    func testUpdateObjectAppendsExactlyOneObjectUpdatedEvent() async throws {
        let configuration = makeInMemoryConfiguration()
        let engine = DefaultVaultEngine(configuration: configuration)
        let vaultId = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        let objectId = try await engine.createObject(
            VaultObjectDraft(
                type: .secureNote,
                metadata: VaultMetadata(title: "Original"),
                payload: VaultPayload(fields: ["body": .secureText("one")])
            )
        )

        _ = try await engine.updateObject(
            VaultObjectUpdate(objectId: objectId, metadata: VaultMetadata(title: "Updated"))
        )
        let updateEvents = try await configuration.eventEngine.listEvents(for: vaultId)
            .filter { $0.type == .objectUpdated && $0.objectId == objectId }

        XCTAssertEqual(updateEvents.count, 1)
    }

    func testUpdateObjectEventIncludesUpdatedObjectVersion() async throws {
        let configuration = makeInMemoryConfiguration()
        let engine = DefaultVaultEngine(configuration: configuration)
        let vaultId = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        let objectId = try await engine.createObject(
            VaultObjectDraft(
                type: .secureNote,
                metadata: VaultMetadata(title: "Original"),
                payload: VaultPayload(fields: ["body": .secureText("one")])
            )
        )

        _ = try await engine.updateObject(
            VaultObjectUpdate(objectId: objectId, metadata: VaultMetadata(title: "Updated"))
        )
        let updateEvent = try await configuration.eventEngine.listEvents(for: vaultId)
            .first { $0.type == .objectUpdated && $0.objectId == objectId }

        XCTAssertEqual(updateEvent?.objectVersion, 2)
    }

    func testUpdateObjectStorageFailureLeavesNoEvent() async throws {
        let storage = InMemoryStorageEngine()
        let eventEngine = InMemoryEventEngine()
        let configuration = makeInMemoryConfiguration(storageEngine: storage, eventEngine: eventEngine)
        let engine = DefaultVaultEngine(configuration: configuration)
        let vaultId = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        let objectId = try await engine.createObject(
            VaultObjectDraft(
                type: .secureNote,
                metadata: VaultMetadata(title: "Original"),
                payload: VaultPayload(fields: ["body": .secureText("one")])
            )
        )
        await storage.failNextUpdate()

        await XCTAssertThrowsVaultError(.unsupportedOperation("Injected storage update failure.")) {
            _ = try await engine.updateObject(
                VaultObjectUpdate(objectId: objectId, metadata: VaultMetadata(title: "Updated"))
            )
        }
        let updateEvents = try await eventEngine.listEvents(for: vaultId)
            .filter { $0.type == .objectUpdated }
        XCTAssertTrue(updateEvents.isEmpty)
    }

    func testUpdateObjectEventFailureRollsBackObjectUpdate() async throws {
        let storage = InMemoryStorageEngine()
        let eventEngine = InMemoryEventEngine()
        let configuration = makeInMemoryConfiguration(storageEngine: storage, eventEngine: eventEngine)
        let engine = DefaultVaultEngine(configuration: configuration)
        _ = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        let objectId = try await engine.createObject(
            VaultObjectDraft(
                type: .secureNote,
                metadata: VaultMetadata(title: "Original"),
                payload: VaultPayload(fields: ["body": .secureText("one")])
            )
        )
        await eventEngine.failNextAppend()

        await XCTAssertThrowsVaultError(.unsupportedOperation("Injected event append failure.")) {
            _ = try await engine.updateObject(
                VaultObjectUpdate(objectId: objectId, metadata: VaultMetadata(title: "Updated"))
            )
        }
        let detail = try await engine.getObjectDetail(id: objectId)
        XCTAssertEqual(detail.metadata.title, "Original")
        XCTAssertEqual(detail.version, 1)
    }

    func testFailedUpdateDoesNotChangeStoredVersion() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        _ = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        let objectId = try await engine.createObject(
            VaultObjectDraft(
                type: .secureNote,
                metadata: VaultMetadata(title: "Original"),
                payload: VaultPayload(fields: ["body": .secureText("one")])
            )
        )

        await XCTAssertThrowsVaultError(.invalidInput("Object title must not be empty.")) {
            _ = try await engine.updateObject(
                VaultObjectUpdate(objectId: objectId, metadata: VaultMetadata(title: " "))
            )
        }

        let detail = try await engine.getObjectDetail(id: objectId)
        XCTAssertEqual(detail.version, 1)
    }

    func testSearchFailsWhenLocked() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        let vaultId = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        await engine.lockVault(id: vaultId)

        await XCTAssertThrowsVaultError(.locked) {
            _ = try await engine.searchObjects(query: "anything")
        }
    }

    func testSearchReturnsMatchingTitle() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        _ = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        let objectId = try await engine.createObject(
            VaultObjectDraft(
                type: .secureNote,
                metadata: VaultMetadata(title: "Launch Checklist"),
                payload: VaultPayload(fields: ["body": .secureText("secret")])
            )
        )

        let results = try await engine.searchObjects(query: "Launch")

        XCTAssertEqual(results.map(\.id), [objectId])
    }

    func testSearchReturnsMatchingTag() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        _ = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        let objectId = try await engine.createObject(
            VaultObjectDraft(
                type: .identity,
                metadata: VaultMetadata(title: "Passport", tags: ["Travel"]),
                payload: VaultPayload(fields: ["number": .secureText("123")])
            )
        )

        let results = try await engine.searchObjects(query: "travel")

        XCTAssertEqual(results.map(\.id), [objectId])
    }

    func testSearchIsCaseInsensitive() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        _ = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        let objectId = try await engine.createObject(
            VaultObjectDraft(
                type: .card,
                metadata: VaultMetadata(title: "Corporate Card"),
                payload: VaultPayload(fields: ["last4": .secureText("4242")])
            )
        )

        let titleResults = try await engine.searchObjects(query: "corporate")
        let typeResults = try await engine.searchObjects(query: "CARD")

        XCTAssertEqual(titleResults.map(\.id), [objectId])
        XCTAssertEqual(typeResults.map(\.id), [objectId])
    }

    func testLockVaultClearsSearchIndex() async throws {
        let configuration = makeInMemoryConfiguration()
        let engine = DefaultVaultEngine(configuration: configuration)
        let vaultId = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        _ = try await engine.createObject(
            VaultObjectDraft(
                type: .secureNote,
                metadata: VaultMetadata(title: "Launch Checklist"),
                payload: VaultPayload(fields: ["body": .secureText("secret")])
            )
        )

        await engine.lockVault(id: vaultId)

        let indexedSummaries = try await configuration.searchEngine.all()
        XCTAssertTrue(indexedSummaries.isEmpty)
    }

    func testUnlockVaultRebuildsSearchIndex() async throws {
        let configuration = makeInMemoryConfiguration()
        let engine = DefaultVaultEngine(configuration: configuration)
        let vaultId = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        let objectId = try await engine.createObject(
            VaultObjectDraft(
                type: .secureNote,
                metadata: VaultMetadata(title: "Launch Checklist"),
                payload: VaultPayload(fields: ["body": .secureText("secret")])
            )
        )
        await engine.lockVault(id: vaultId)

        try await engine.unlockVault(id: vaultId, using: .biometric)

        let results = try await engine.searchObjects(query: "launch")
        XCTAssertEqual(results.map(\.id), [objectId])
    }

    func testMoveToTrashRemovesItemFromSearch() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        _ = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        let objectId = try await engine.createObject(
            VaultObjectDraft(
                type: .secureNote,
                metadata: VaultMetadata(title: "Trash Search"),
                payload: VaultPayload(fields: ["body": .secureText("secret")])
            )
        )

        try await engine.moveToTrash(objectId)

        let results = try await engine.searchObjects(query: "Trash")
        XCTAssertTrue(results.isEmpty)
    }

    func testRestoreFromTrashAddsItemBackToSearch() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        _ = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        let objectId = try await engine.createObject(
            VaultObjectDraft(
                type: .secureNote,
                metadata: VaultMetadata(title: "Restore Search"),
                payload: VaultPayload(fields: ["body": .secureText("secret")])
            )
        )
        try await engine.moveToTrash(objectId)

        try await engine.restoreFromTrash(objectId)

        let results = try await engine.searchObjects(query: "restore")
        XCTAssertEqual(results.map(\.id), [objectId])
    }

    func testBlobWriteCreatesBlobWriteResult() async throws {
        let blobStore = InMemoryBlobStore()

        let result = try await blobStore.writeBlob(Data([1, 2, 3]), contentType: "application/pdf")

        XCTAssertEqual(result.byteCount, 3)
        XCTAssertEqual(result.contentType, "application/pdf")
        XCTAssertEqual(result.record.id, result.id)
        XCTAssertEqual(result.record.role, .original)
        XCTAssertFalse(result.record.encryptionMetadata.isPlaintextPersisted)
    }

    func testBlobExistsReturnsTrueAfterWrite() async throws {
        let blobStore = InMemoryBlobStore()

        let result = try await blobStore.writeBlob(Data([1, 2, 3]), contentType: "application/pdf")

        let exists = try await blobStore.blobExists(id: result.id)
        XCTAssertTrue(exists)
    }

    func testBlobReadReturnsStoredData() async throws {
        let blobStore = InMemoryBlobStore()
        let data = Data("stored document".utf8)

        let result = try await blobStore.writeBlob(data, contentType: "application/pdf")

        let storedData = try await blobStore.readBlob(id: result.id)
        XCTAssertEqual(storedData, data)
    }

    func testBlobDeleteRemovesBlob() async throws {
        let blobStore = InMemoryBlobStore()
        let result = try await blobStore.writeBlob(Data([1, 2, 3]), contentType: "application/pdf")

        try await blobStore.deleteBlob(id: result.id)

        let exists = try await blobStore.blobExists(id: result.id)
        XCTAssertFalse(exists)
    }

    func testFileSystemBlobStoreUsesShardedBlobPath() async throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SecureVaultKitBlobStore-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let blobStore = try FileSystemBlobStore(rootDirectory: directoryURL)
        let fileURL = try makeTemporaryDocument(fileName: "stored.pdf", contents: Data([4, 5, 6, 7]))
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let result = try await blobStore.writeBlob(from: fileURL, contentType: "application/pdf")
        let storedData = try await blobStore.readBlob(id: result.id)
        let storedPath = try XCTUnwrap(result.record.storagePath)
        let persistedData = try Data(contentsOf: directoryURL.appendingPathComponent(storedPath))

        XCTAssertEqual(result.byteCount, 4)
        XCTAssertEqual(result.record.storagePath, "blobs/\(String(result.id.rawValue.prefix(2)))/\(result.id.rawValue).blob")
        XCTAssertEqual(storedData, Data([4, 5, 6, 7]))
        XCTAssertNotEqual(persistedData, Data([4, 5, 6, 7]))
        XCTAssertFalse(result.record.encryptionMetadata.isPlaintextPersisted)
    }

    func testImageThumbnailGeneration() async throws {
        let workspace = try TemporaryWorkspace()
        defer { workspace.cleanup() }
        let document = try makeStagedDocument(
            fileName: "photo.png",
            contentType: "image/png",
            contents: Data([1, 2, 3]),
            workspace: workspace
        )

        let asset = try await ImageThumbnailGenerator().generateThumbnail(for: document, in: workspace)

        XCTAssertEqual(asset.role, .thumbnail)
        XCTAssertEqual(asset.contentType, "image/png")
        XCTAssertTrue(FileManager.default.fileExists(atPath: asset.fileURL.path))
        XCTAssertTrue(try Data(contentsOf: asset.fileURL).contains(Data("image-thumbnail".utf8)))
    }

    func testPDFThumbnailGeneration() async throws {
        let workspace = try TemporaryWorkspace()
        defer { workspace.cleanup() }
        let document = try makeStagedDocument(
            fileName: "report.pdf",
            contentType: "application/pdf",
            contents: Data("%PDF fake".utf8),
            workspace: workspace
        )

        let asset = try await PDFThumbnailGenerator().generateThumbnail(for: document, in: workspace)

        XCTAssertEqual(asset.role, .thumbnail)
        XCTAssertEqual(asset.contentType, "image/png")
        XCTAssertTrue(FileManager.default.fileExists(atPath: asset.fileURL.path))
        XCTAssertTrue(try Data(contentsOf: asset.fileURL).contains(Data("pdf-thumbnail".utf8)))
    }

    func testPreviewGeneration() async throws {
        let workspace = try TemporaryWorkspace()
        defer { workspace.cleanup() }
        let document = try makeStagedDocument(
            fileName: "report.pdf",
            contentType: "application/pdf",
            contents: Data("%PDF fake".utf8),
            workspace: workspace
        )

        let asset = try await PDFPreviewGenerator().generatePreview(for: document, in: workspace)

        XCTAssertEqual(asset.role, .preview)
        XCTAssertEqual(asset.contentType, "application/pdf")
        XCTAssertTrue(FileManager.default.fileExists(atPath: asset.fileURL.path))
        XCTAssertTrue(try Data(contentsOf: asset.fileURL).contains(Data("pdf-preview".utf8)))
    }

    func testDocumentImportRejectsUnsupportedFile() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        let vaultId = try await createUnlockedVault(using: engine)
        let fileURL = try makeTemporaryDocument(
            fileName: "malware.exe",
            contents: Data([1, 2, 3])
        )
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        await XCTAssertThrowsVaultError(.unsupportedOperation("Unsupported document content type.")) {
            _ = try await engine.importDocument(
                DocumentImportInput(fileURL: fileURL, contentType: "application/octet-stream"),
                into: vaultId
            )
        }
    }

    func testDocumentImportRejectsMissingFile() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        let vaultId = try await createUnlockedVault(using: engine)
        let missingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SecureVaultKitTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("missing.pdf")

        await XCTAssertThrowsVaultError(.invalidInput("Document file does not exist.")) {
            _ = try await engine.importDocument(
                DocumentImportInput(fileURL: missingURL, contentType: "application/pdf"),
                into: vaultId
            )
        }
    }

    func testDocumentImportCreatesDocumentObject() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        let vaultId = try await createUnlockedVault(using: engine)
        let fileURL = try makeTemporaryDocument(fileName: "passport.pdf")
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let result = try await engine.importDocument(
            DocumentImportInput(fileURL: fileURL, contentType: "application/pdf"),
            into: vaultId
        )

        let detail = try await engine.getObjectDetail(id: result.objectId)
        XCTAssertEqual(detail.type, .document)
        XCTAssertEqual(detail.metadata.title, "passport.pdf")
        XCTAssertEqual(detail.payload.fields["contentType"], .text("application/pdf"))
    }

    func testDocumentImportCreatesOriginalAttachment() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        let vaultId = try await createUnlockedVault(using: engine)
        let fileURL = try makeTemporaryDocument(fileName: "statement.pdf", contents: Data([9, 8, 7, 6]))
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let result = try await engine.importDocument(
            DocumentImportInput(fileURL: fileURL, contentType: "application/pdf"),
            into: vaultId
        )

        let detail = try await engine.getObjectDetail(id: result.objectId)
        XCTAssertTrue(detail.payload.attachments.contains(result.attachment))
        XCTAssertEqual(result.attachment.role, .primary)
        XCTAssertEqual(result.attachment.fileName, "statement.pdf")
        XCTAssertEqual(result.attachment.byteCount, 4)
    }

    func testDocumentImportCreatesThumbnailAttachment() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        let vaultId = try await createUnlockedVault(using: engine)
        let fileURL = try makeTemporaryDocument(fileName: "thumbnail-source.pdf")
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let result = try await engine.importDocument(
            DocumentImportInput(fileURL: fileURL, contentType: "application/pdf"),
            into: vaultId
        )

        let detail = try await engine.getObjectDetail(id: result.objectId)
        XCTAssertEqual(result.thumbnailAttachment?.role, .thumbnail)
        XCTAssertEqual(result.thumbnailAttachment?.contentType, "image/png")
        XCTAssertTrue(detail.payload.attachments.contains { $0.role == .thumbnail })
    }

    func testDocumentImportCreatesPreviewAttachment() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        let vaultId = try await createUnlockedVault(using: engine)
        let fileURL = try makeTemporaryDocument(fileName: "preview-source.pdf")
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let result = try await engine.importDocument(
            DocumentImportInput(fileURL: fileURL, contentType: "application/pdf"),
            into: vaultId
        )

        let detail = try await engine.getObjectDetail(id: result.objectId)
        XCTAssertEqual(result.previewAttachment?.role, .preview)
        XCTAssertEqual(result.previewAttachment?.contentType, "application/pdf")
        XCTAssertTrue(detail.payload.attachments.contains { $0.role == .preview })
    }

    func testDocumentImportAppendsAttachmentAddedEvent() async throws {
        let configuration = makeInMemoryConfiguration()
        let engine = DefaultVaultEngine(configuration: configuration)
        let vaultId = try await createUnlockedVault(using: engine)
        let fileURL = try makeTemporaryDocument(fileName: "taxes.pdf")
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let result = try await engine.importDocument(
            DocumentImportInput(fileURL: fileURL, contentType: "application/pdf"),
            into: vaultId
        )

        let events = try await configuration.eventEngine.listEvents(for: vaultId)
        let attachmentEvents = events.filter { $0.type == .attachmentAdded }
        XCTAssertEqual(attachmentEvents.count, 3)
        XCTAssertEqual(Set(attachmentEvents.compactMap(\.blobId)), Set(result.attachments.map(\.id)))
        XCTAssertTrue(attachmentEvents.allSatisfy { $0.objectId == result.objectId })
    }

    func testDocumentImportCleansTemporaryWorkspace() async throws {
        let workspaceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SecureVaultKitImportTest-\(UUID().uuidString)", isDirectory: true)
        let service = DefaultDocumentImportService(
            workspaceFactory: { try TemporaryWorkspace(rootURL: workspaceURL) }
        )
        let engine = DefaultVaultEngine(
            configuration: makeInMemoryConfiguration(),
            documentImportService: service
        )
        let vaultId = try await createUnlockedVault(using: engine)
        let fileURL = try makeTemporaryDocument(fileName: "cleanup.pdf")
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        _ = try await engine.importDocument(
            DocumentImportInput(fileURL: fileURL, contentType: "application/pdf"),
            into: vaultId
        )

        XCTAssertFalse(FileManager.default.fileExists(atPath: workspaceURL.path))
    }

    func testDocumentImportStoresOriginalFileThroughBlobStore() async throws {
        let blobStore = InMemoryBlobStore()
        let configuration = makeInMemoryConfiguration(blobStore: blobStore)
        let engine = DefaultVaultEngine(configuration: configuration)
        let vaultId = try await createUnlockedVault(using: engine)
        let contents = Data("original pdf bytes".utf8)
        let fileURL = try makeTemporaryDocument(fileName: "original.pdf", contents: contents)
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let result = try await engine.importDocument(
            DocumentImportInput(fileURL: fileURL, contentType: "application/pdf"),
            into: vaultId
        )
        let storedData = try await blobStore.readBlob(id: result.attachment.id)
        let blobIds = try await blobStore.listBlobs().map(\.id)

        XCTAssertEqual(storedData, contents)
        XCTAssertEqual(Set(blobIds), Set(result.attachments.map(\.id)))
    }

    func testDocumentImportAttachmentReferencesBlobID() async throws {
        let blobStore = InMemoryBlobStore()
        let configuration = makeInMemoryConfiguration(blobStore: blobStore)
        let engine = DefaultVaultEngine(configuration: configuration)
        let vaultId = try await createUnlockedVault(using: engine)
        let fileURL = try makeTemporaryDocument(fileName: "attached.pdf")
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let result = try await engine.importDocument(
            DocumentImportInput(fileURL: fileURL, contentType: "application/pdf"),
            into: vaultId
        )

        let blobs = try await blobStore.listBlobs()
        XCTAssertTrue(blobs.contains { $0.id == result.attachment.id })
    }

    func testDocumentImportStoresThumbnailAndPreviewWithProtectedBlobMetadata() async throws {
        let blobStore = InMemoryBlobStore()
        let configuration = makeInMemoryConfiguration(blobStore: blobStore)
        let engine = DefaultVaultEngine(configuration: configuration)
        let vaultId = try await createUnlockedVault(using: engine)
        let fileURL = try makeTemporaryDocument(fileName: "protected-assets.pdf")
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let result = try await engine.importDocument(
            DocumentImportInput(fileURL: fileURL, contentType: "application/pdf"),
            into: vaultId
        )

        let records = try await blobStore.listBlobs()
        XCTAssertEqual(Set(records.map(\.role)), [.original, .thumbnail, .preview])
        XCTAssertEqual(records.first { $0.id == result.thumbnailAttachment?.id }?.role, .thumbnail)
        XCTAssertEqual(records.first { $0.id == result.previewAttachment?.id }?.role, .preview)
        XCTAssertTrue(records.allSatisfy { !$0.encryptionMetadata.isPlaintextPersisted })
    }

    func testBlobWriteFailurePreventsObjectCreation() async throws {
        let blobStore = InMemoryBlobStore()
        let configuration = makeInMemoryConfiguration(blobStore: blobStore)
        let engine = DefaultVaultEngine(configuration: configuration)
        let vaultId = try await createUnlockedVault(using: engine)
        let fileURL = try makeTemporaryDocument(fileName: "blocked.pdf")
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }
        await blobStore.failNextWrite()

        await XCTAssertThrowsVaultError(.unsupportedOperation("Injected blob write failure.")) {
            _ = try await engine.importDocument(
                DocumentImportInput(fileURL: fileURL, contentType: "application/pdf"),
                into: vaultId
            )
        }

        let summaries = try await engine.listObjects(filter: VaultObjectFilter())
        XCTAssertTrue(summaries.isEmpty)
    }

    func testBlobWriteFailurePreventsAttachmentAddedEvent() async throws {
        let blobStore = InMemoryBlobStore()
        let configuration = makeInMemoryConfiguration(blobStore: blobStore)
        let engine = DefaultVaultEngine(configuration: configuration)
        let vaultId = try await createUnlockedVault(using: engine)
        let fileURL = try makeTemporaryDocument(fileName: "blocked-event.pdf")
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }
        await blobStore.failNextWrite()

        await XCTAssertThrowsVaultError(.unsupportedOperation("Injected blob write failure.")) {
            _ = try await engine.importDocument(
                DocumentImportInput(fileURL: fileURL, contentType: "application/pdf"),
                into: vaultId
            )
        }

        let events = try await configuration.eventEngine.listEvents(for: vaultId)
        XCTAssertFalse(events.contains { $0.type == .attachmentAdded })
    }

    func testDependenciesAreUsableThroughFakes() async throws {
        let configuration = makeInMemoryConfiguration()
        let vaultId = VaultID("vault-1")
        let deviceId = DeviceID("device-1")
        let key = try await configuration.cryptoEngine.deriveVaultKey(for: vaultId, using: .passphrase)
        let wrappedKey = try await configuration.cryptoEngine.wrapKey(key, for: deviceId)
        let header = VaultHeaderRecord(
            vaultId: vaultId,
            name: "Primary",
            primaryDeviceId: deviceId,
            rootKey: wrappedKey,
            vaultEncryptionKey: wrappedKey
        )

        try await configuration.storageEngine.writeVaultHeader(header)
        let storedHeader = try await configuration.storageEngine.readVaultHeader(vaultId: vaultId)
        XCTAssertEqual(storedHeader, header)

        let blobResult = try await configuration.blobStore.writeBlob(Data([1, 2, 3]), contentType: "application/octet-stream")
        XCTAssertEqual(blobResult.byteCount, 3)
        let storedBlob = try await configuration.blobStore.readBlob(id: blobResult.id)
        XCTAssertEqual(storedBlob, Data([1, 2, 3]))

        let event = VaultEvent(vaultId: vaultId, type: .vaultCreated)
        try await configuration.eventEngine.append(event)
        let storedEvents = try await configuration.eventEngine.events(for: vaultId)
        XCTAssertEqual(storedEvents, [event])

        let identity = try await configuration.deviceTrustEngine.currentDeviceIdentity()
        try await configuration.deviceTrustEngine.trustDevice(identity, for: vaultId)
        let trustedDevices = try await configuration.deviceTrustEngine.trustedDevices(for: vaultId)
        XCTAssertEqual(trustedDevices, [identity])

        let encryptedPayload = try await configuration.cryptoEngine.encryptPayload(VaultPayload(), using: key)
        let record = VaultObjectRecord(
            id: VaultObjectID("object-1"),
            vaultId: vaultId,
            type: .secureNote,
            encryptedMetadata: try await configuration.cryptoEngine.encryptMetadata(VaultMetadata(title: "Indexed"), using: key),
            encryptedPayload: encryptedPayload,
            wrappedItemKey: wrappedKey
        )
        try await configuration.searchEngine.indexObject(record)
        let searchResults = try await configuration.searchEngine.search(in: vaultId, matching: VaultObjectFilter())
        XCTAssertEqual(searchResults, [record.id])
    }

    private func createUnlockedVault(using engine: DefaultVaultEngine) async throws -> VaultID {
        try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
    }

    private func makeTemporaryDocument(
        fileName: String,
        contents: Data = Data("fake document".utf8)
    ) throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SecureVaultKitTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let fileURL = directoryURL.appendingPathComponent(fileName)
        try contents.write(to: fileURL)
        return fileURL
    }

    private func makeStagedDocument(
        fileName: String,
        contentType: String,
        contents: Data,
        workspace: TemporaryWorkspace
    ) throws -> StagedDocument {
        let fileURL = try workspace.writeGeneratedFile(fileName: fileName, data: contents)
        return StagedDocument(
            url: fileURL,
            data: contents,
            metadata: ImportedDocumentMetadata(
                fileName: fileName,
                contentType: contentType,
                byteCount: contents.count,
                fileExtension: fileURL.pathExtension
            )
        )
    }
}
