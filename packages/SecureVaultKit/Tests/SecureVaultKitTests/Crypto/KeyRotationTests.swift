import Foundation
import XCTest
@testable import SecureVaultKit

final class KeyRotationTests: XCTestCase {
    func testRegisterKeyStoresKeyVersion() async throws {
        let registry = InMemoryKeyRegistry()
        let key = makeKey()

        try await registry.registerKey(key)

        let keys = await registry.listKeys()
        XCTAssertEqual(keys, [key])
    }

    func testGetActiveKeyReturnsCurrentActiveKey() async throws {
        let registry = InMemoryKeyRegistry(keys: [
            makeKey(id: "vek-v1", version: 1),
            makeKey(id: "vek-v2", version: 2)
        ])

        let activeKey = try await registry.getActiveKey()

        XCTAssertEqual(activeKey.keyId, KeyIdentifier("vek-v2"))
    }

    func testRetireKeyMarksKeyRetired() async throws {
        let registry = InMemoryKeyRegistry(keys: [makeKey()])
        let retiredAt = Date(timeIntervalSince1970: 200)

        try await registry.retireKey("vek-v1", at: retiredAt)

        let keys = await registry.listKeys()
        let key = try XCTUnwrap(keys.first)
        XCTAssertEqual(key.state, .retired)
        XCTAssertEqual(key.retiredAt, retiredAt)
    }

    func testMarkCompromisedMarksKeyCompromised() async throws {
        let registry = InMemoryKeyRegistry(keys: [makeKey()])

        try await registry.markCompromised("vek-v1")

        let keys = await registry.listKeys()
        let key = try XCTUnwrap(keys.first)
        XCTAssertEqual(key.state, .compromised)
    }

    func testCreateRotationPlanIncludesOldAndNewKeyIds() async throws {
        let engine = makeEngine()

        let plan = try await engine.createRotationPlan(for: "vek-v1")

        XCTAssertEqual(plan.oldKeyId, KeyIdentifier("vek-v1"))
        XCTAssertEqual(plan.newKeyId, KeyIdentifier("vek-v1-v2"))
        XCTAssertNotEqual(plan.oldKeyId, plan.newKeyId)
    }

    func testRotationPlanCanIncludeObjectIds() async throws {
        let objectId = VaultObjectID("object-1")
        let engine = makeEngine(objectIds: [objectId])

        let plan = try await engine.createRotationPlan(for: "vek-v1")

        XCTAssertEqual(plan.affectedObjectIds, [objectId])
    }

    func testRotationPlanCanIncludeBlobIds() async throws {
        let blobId = BlobID("blob-1")
        let engine = makeEngine(blobIds: [blobId])

        let plan = try await engine.createRotationPlan(for: "vek-v1")

        XCTAssertEqual(plan.affectedBlobIds, [blobId])
    }

    func testEncryptedEnvelopePreservesKeyId() throws {
        let envelope = EncryptedEnvelope(
            version: 1,
            algorithm: .aesGCM,
            keyId: "item-key-v3",
            nonce: Data([1]),
            ciphertext: Data([2])
        )

        let encoded = try JSONEncoder().encode(envelope)
        let decoded = try JSONDecoder().decode(EncryptedEnvelope.self, from: encoded)

        XCTAssertEqual(decoded.keyId, KeyIdentifier("item-key-v3"))
    }

    func testWrappedKeyPreservesWrappingKeyId() throws {
        let wrappedKey = WrappedKey(
            keyId: "item-key-v2",
            wrappingKeyId: "vek-v4",
            wrappedData: Data([1, 2]),
            algorithm: .aesGCM
        )

        let encoded = try JSONEncoder().encode(wrappedKey)
        let decoded = try JSONDecoder().decode(WrappedKey.self, from: encoded)

        XCTAssertEqual(decoded.wrappingKeyId, KeyIdentifier("vek-v4"))
    }

    private func makeEngine(
        objectIds: [VaultObjectID] = [],
        blobIds: [BlobID] = []
    ) -> FakeKeyRotationEngine {
        let keyId = KeyIdentifier("vek-v1")
        let registry = InMemoryKeyRegistry(keys: [makeKey()])
        return FakeKeyRotationEngine(
            keyRegistry: registry,
            objectIdsByKeyId: [keyId: objectIds],
            blobIdsByKeyId: [keyId: blobIds]
        )
    }

    private func makeKey(
        id: KeyIdentifier = "vek-v1",
        version: Int = 1
    ) -> KeyVersion {
        KeyVersion(
            keyId: id,
            versionNumber: version,
            createdAt: Date(timeIntervalSince1970: TimeInterval(version)),
            state: .active
        )
    }
}
