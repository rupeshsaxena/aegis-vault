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

    func testPersistentLocalEngineDocumentMetadataBlobRecordAndThumbnailSurviveEngineRecreation() async throws {
        let storageURL = try makeTemporaryStorageURL()
        let vaultId: VaultID
        let documentId: VaultObjectID
        do {
            let engine = try VaultEngineFactory.makePersistentLocalEngine(storageURL: storageURL)
            vaultId = try await engine.createVault(config: persistentTestVaultConfig())
            let result = try await engine.importDocument(
                DocumentImportInput(
                    fileName: "receipt.pdf",
                    contentType: "application/pdf",
                    data: Data("SECURITY_MARKER_BLOB_CONTENT_E175".utf8)
                ),
                into: vaultId
            )
            documentId = result.objectId
            XCTAssertNotNil(result.thumbnailAttachment)
            await engine.lockVault()
        }

        let reopenedEngine = try VaultEngineFactory.makePersistentLocalEngine(storageURL: storageURL)
        try await reopenedEngine.unlockVault(method: .recoverySecret("valid-secret"))
        let detail = try await reopenedEngine.getObjectDetail(id: documentId)
        let thumbnail = try await reopenedEngine.loadThumbnail(for: documentId)
        let storage = try SQLiteStorageEngine(databaseURL: storageURL.appendingPathComponent("vault.sqlite"))
        let blobRecords = try await storage.listPersistedBlobRecords()
        let events = try await storage.listPersistedEvents(for: vaultId)

        XCTAssertEqual(detail.type, .document)
        XCTAssertEqual(detail.metadata.title, "receipt.pdf")
        XCTAssertEqual(detail.payload.fields["fileName"], .text("receipt.pdf"))
        XCTAssertFalse(thumbnail.data.isEmpty)
        XCTAssertTrue(blobRecords.contains { $0.role == .original })
        XCTAssertTrue(blobRecords.contains { $0.role == .thumbnail && $0.encryptedEnvelope != nil && $0.wrappedKey != nil })
        XCTAssertTrue(events.contains { $0.type == .objectCreated && $0.objectId == documentId })
        XCTAssertTrue(events.contains { $0.type == .attachmentAdded && $0.objectId == documentId })
    }

    func testPersistentLocalEngineRawSQLiteDoesNotContainSensitiveMarkers() async throws {
        let storageURL = try makeTemporaryStorageURL()
        do {
            let engine = try VaultEngineFactory.makePersistentLocalEngine(storageURL: storageURL)
            _ = try await engine.createVault(config: persistentTestVaultConfig())
            _ = try await engine.createObject(
                persistentTestNoteDraft(
                    title: "SECURITY_MARKER_PASSPORT_TITLE_7A91",
                    notes: "SECURITY_MARKER_NOTE_BODY_8B42"
                )
            )
            _ = try await engine.createObject(
                persistentTestIdentityDraft(
                    title: "Identity",
                    documentNumber: "SECURITY_MARKER_DOCUMENT_NUMBER_9C53"
                )
            )
            _ = try await engine.createObject(
                persistentTestCardDraft(
                    title: "Card",
                    cardNumber: "SECURITY_MARKER_CARD_NUMBER_0D64"
                )
            )
            await engine.lockVault()
        }

        let markers = [
            "SECURITY_MARKER_PASSPORT_TITLE_7A91",
            "SECURITY_MARKER_NOTE_BODY_8B42",
            "SECURITY_MARKER_DOCUMENT_NUMBER_9C53",
            "SECURITY_MARKER_CARD_NUMBER_0D64"
        ]

        for url in sqliteSidecarURLs(in: storageURL) where FileManager.default.fileExists(atPath: url.path) {
            let bytes = try Data(contentsOf: url)
            for marker in markers {
                XCTAssertNil(
                    bytes.range(of: Data(marker.utf8)),
                    "\(marker) leaked into \(url.lastPathComponent)"
                )
            }
        }
    }

    func testPersistentLocalEngineBlobFilesDoNotContainPlaintextMarker() async throws {
        let storageURL = try makeTemporaryStorageURL()
        let marker = "SECURITY_MARKER_BLOB_CONTENT_E175"
        do {
            let engine = try VaultEngineFactory.makePersistentLocalEngine(storageURL: storageURL)
            let vaultId = try await engine.createVault(config: persistentTestVaultConfig())
            _ = try await engine.importDocument(
                DocumentImportInput(
                    fileName: "marker.pdf",
                    contentType: "application/pdf",
                    data: Data(marker.utf8)
                ),
                into: vaultId
            )
            await engine.lockVault()
        }

        let blobFiles = try blobFileURLs(in: storageURL)
        XCTAssertFalse(blobFiles.isEmpty)
        for blobFile in blobFiles {
            let bytes = try Data(contentsOf: blobFile)
            XCTAssertNil(bytes.range(of: Data(marker.utf8)), "\(marker) leaked into \(blobFile.lastPathComponent)")
        }
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

    private func persistentTestNoteDraft(
        title: String,
        notes: String = "This note should survive engine recreation."
    ) -> VaultObjectDraft {
        VaultObjectDraft(
            type: .secureNote,
            metadata: VaultMetadata(title: title, tags: ["persistence"]),
            payload: VaultPayload(notes: notes)
        )
    }

    private func persistentTestIdentityDraft(
        title: String = "Passport",
        documentNumber: String = "P1234567"
    ) -> VaultObjectDraft {
        VaultObjectDraft(
            type: .identity,
            metadata: VaultMetadata(
                title: title,
                category: "passport",
                tags: ["travel", "identity"]
            ),
            payload: VaultPayload(
                notes: "Identity should survive engine recreation.",
                fields: [
                    "identityType": .text("passport"),
                    "fullName": .text("Taylor Smith"),
                    "documentNumber": .secureText(documentNumber)
                ]
            )
        )
    }

    private func persistentTestCardDraft(
        title: String = "Travel Card",
        cardNumber: String = "4111111111111111"
    ) -> VaultObjectDraft {
        VaultObjectDraft(
            type: .card,
            metadata: VaultMetadata(
                title: title,
                category: "creditCard",
                tags: ["travel", "finance"]
            ),
            payload: VaultPayload(
                notes: "Card should survive engine recreation.",
                fields: [
                    "cardType": .text("creditCard"),
                    "cardholderName": .text("Taylor Smith"),
                    "cardNumber": .secureText(cardNumber),
                    "expiryMonth": .text("12"),
                    "expiryYear": .text("2030")
                ]
            )
        )
    }

    private func sqliteSidecarURLs(in storageURL: URL) -> [URL] {
        [
            storageURL.appendingPathComponent("vault.sqlite"),
            storageURL.appendingPathComponent("vault.sqlite-wal"),
            storageURL.appendingPathComponent("vault.sqlite-shm")
        ]
    }

    private func blobFileURLs(in storageURL: URL) throws -> [URL] {
        let blobDirectory = storageURL.appendingPathComponent("blobs", isDirectory: true)
        guard let enumerator = FileManager.default.enumerator(
            at: blobDirectory,
            includingPropertiesForKeys: [.isRegularFileKey]
        ) else {
            return []
        }
        return try enumerator.compactMap { item in
            guard let url = item as? URL else { return nil }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            return values.isRegularFile == true ? url : nil
        }
    }
}
