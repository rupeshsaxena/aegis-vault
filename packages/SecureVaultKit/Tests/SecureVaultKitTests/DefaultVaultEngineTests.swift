import Foundation
import XCTest
@testable import SecureVaultKit

final class DefaultVaultEngineTests: XCTestCase {
    func testDefaultVaultEngineCanInitialize() {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())

        XCTAssertNotNil(engine)
    }

    func testCreateVaultCreatesUnlockedSession() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
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
            XCTAssertNotNil(session.keyReferences.vaultKeyReference)
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

    func testCreateObjectThrowsUnsupportedOperationWhileNotImplemented() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        let draft = VaultObjectDraft(
            type: .secureNote,
            metadata: VaultMetadata(title: "Note"),
            payload: VaultPayload(fields: ["body": .secureText("secret")])
        )

        await XCTAssertThrowsVaultError(VaultError.unsupportedOperation("Object creation is not implemented yet.")) {
            _ = try await engine.createObject(draft, in: VaultID("vault-1"))
        }
    }

    func testDependenciesAreUsableThroughFakes() async throws {
        let configuration = makeInMemoryConfiguration()
        let vaultId = VaultID("vault-1")
        let deviceId = DeviceID("device-1")
        let key = try await configuration.cryptoEngine.deriveVaultKey(for: vaultId, using: .passphrase)
        let wrappedKey = try await configuration.cryptoEngine.wrapKey(key, for: deviceId)
        let header = VaultHeaderRecord(vaultId: vaultId, primaryDeviceId: deviceId, wrappedKey: wrappedKey)

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
            metadata: VaultMetadata(title: "Indexed"),
            encryptedPayload: encryptedPayload
        )
        try await configuration.searchEngine.indexObject(record)
        let searchResults = try await configuration.searchEngine.search(in: vaultId, matching: VaultObjectFilter())
        XCTAssertEqual(searchResults, [record.id])
    }
}
