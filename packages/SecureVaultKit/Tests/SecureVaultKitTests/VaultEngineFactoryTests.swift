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

        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(summaries.map(\.id), [createdObjectId])
        XCTAssertEqual(summaries.first?.title, "Relaunch Note")
        XCTAssertEqual(summaries.first?.type, .secureNote)
        XCTAssertEqual(detail.id, createdObjectId)
        XCTAssertEqual(detail.metadata.title, "Relaunch Note")
        XCTAssertEqual(detail.type, .secureNote)
        XCTAssertEqual(detail.payload.notes, "This note should survive engine recreation.")
    }

    func testPersistentLocalEngineIdentityAndCardSurviveEngineRecreation() async throws {
        let storageURL = try makeTemporaryStorageURL()
        let identityId: VaultObjectID
        let cardId: VaultObjectID
        do {
            let engine = try VaultEngineFactory.makePersistentLocalEngine(storageURL: storageURL)
            _ = try await engine.createVault(config: persistentTestVaultConfig())
            identityId = try await engine.createObject(persistentTestIdentityDraft())
            cardId = try await engine.createObject(persistentTestCardDraft())
            await engine.lockVault()
        }

        let reopenedEngine = try VaultEngineFactory.makePersistentLocalEngine(storageURL: storageURL)
        try await reopenedEngine.unlockVault(method: .recoverySecret("valid-secret"))
        let summaries = try await reopenedEngine.listObjects(filter: VaultObjectFilter())
        let identityDetail = try await reopenedEngine.getObjectDetail(id: identityId)
        let cardDetail = try await reopenedEngine.getObjectDetail(id: cardId)

        XCTAssertEqual(summaries.count, 2)
        XCTAssertEqual(Set(summaries.map(\.id)), Set([identityId, cardId]))
        XCTAssertTrue(summaries.contains { $0.id == identityId && $0.type == .identity && $0.title == "Passport" })
        XCTAssertTrue(summaries.contains { $0.id == cardId && $0.type == .card && $0.title == "Travel Card" })
        XCTAssertEqual(identityDetail.type, .identity)
        XCTAssertEqual(identityDetail.metadata.title, "Passport")
        XCTAssertEqual(identityDetail.metadata.category, "passport")
        XCTAssertEqual(identityDetail.payload.fields["documentNumber"], .secureText("P1234567"))
        XCTAssertEqual(cardDetail.type, .card)
        XCTAssertEqual(cardDetail.metadata.title, "Travel Card")
        XCTAssertEqual(cardDetail.metadata.category, "creditCard")
        XCTAssertEqual(cardDetail.payload.fields["cardNumber"], .secureText("4111111111111111"))
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

    func testPersistentLocalEngineDeletedIdentityAndCardStateSurvivesEngineRecreation() async throws {
        let storageURL = try makeTemporaryStorageURL()
        let identityId: VaultObjectID
        let cardId: VaultObjectID
        do {
            let engine = try VaultEngineFactory.makePersistentLocalEngine(storageURL: storageURL)
            _ = try await engine.createVault(config: persistentTestVaultConfig())
            identityId = try await engine.createObject(persistentTestIdentityDraft())
            cardId = try await engine.createObject(persistentTestCardDraft())
            try await engine.moveToTrash(identityId)
            try await engine.moveToTrash(cardId)
            await engine.lockVault()
        }

        let reopenedEngine = try VaultEngineFactory.makePersistentLocalEngine(storageURL: storageURL)
        try await reopenedEngine.unlockVault(method: .recoverySecret("valid-secret"))
        let visibleObjects = try await reopenedEngine.listObjects(filter: VaultObjectFilter())
        let deletedObjects = try await reopenedEngine.listObjects(
            filter: VaultObjectFilter(includeDeleted: true)
        )

        XCTAssertFalse(visibleObjects.contains { $0.id == identityId || $0.id == cardId })
        XCTAssertTrue(deletedObjects.contains { $0.id == identityId && $0.type == .identity && $0.isDeleted })
        XCTAssertTrue(deletedObjects.contains { $0.id == cardId && $0.type == .card && $0.isDeleted })
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

    private func persistentTestIdentityDraft() -> VaultObjectDraft {
        VaultObjectDraft(
            type: .identity,
            metadata: VaultMetadata(
                title: "Passport",
                category: "passport",
                tags: ["travel", "identity"]
            ),
            payload: VaultPayload(
                notes: "Identity should survive engine recreation.",
                fields: [
                    "identityType": .text("passport"),
                    "fullName": .text("Taylor Smith"),
                    "documentNumber": .secureText("P1234567")
                ]
            )
        )
    }

    private func persistentTestCardDraft() -> VaultObjectDraft {
        VaultObjectDraft(
            type: .card,
            metadata: VaultMetadata(
                title: "Travel Card",
                category: "creditCard",
                tags: ["travel", "finance"]
            ),
            payload: VaultPayload(
                notes: "Card should survive engine recreation.",
                fields: [
                    "cardType": .text("creditCard"),
                    "cardholderName": .text("Taylor Smith"),
                    "cardNumber": .secureText("4111111111111111"),
                    "expiryMonth": .text("12"),
                    "expiryYear": .text("2030")
                ]
            )
        )
    }
}
