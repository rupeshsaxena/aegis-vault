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
        XCTAssertEqual(events.map(\.type), [.vaultCreated])
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

        XCTAssertEqual(record.encryptedMetadata.algorithm, "in-memory.fake.metadata")
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
}
