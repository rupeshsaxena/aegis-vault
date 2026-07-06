import Foundation
import SecureVaultKit
import XCTest
@testable import AegisVault

final class ApplicationServiceTests: XCTestCase {
    func testSecureNoteApplicationServiceCreateUpdateLoad() async throws {
        let detail = makeDetail(type: .secureNote)
        let create = SecureNoteCreateSpy(result: .success(VaultObjectID("note")))
        let update = SecureNoteUpdateSpy(result: .success(VaultObjectID("note")))
        let detailLoader = DetailSpy(result: .success(detail))
        let mutation = ObjectMutationSpy()
        let service = SecureNoteApplicationService(
            createUseCase: create,
            updateUseCase: update,
            detailUseCase: detailLoader,
            moveToTrashUseCase: mutation,
            restoreUseCase: mutation
        )

        let createdID = try await service.createNote(SecureNoteEditorViewData(title: "Note", content: "Body"))
        let loaded = try await service.loadNote(id: detail.id)
        let updatedID = try await service.updateNote(existing: detail, data: SecureNoteEditorViewData(title: "Updated"))

        XCTAssertEqual(createdID, VaultObjectID("note"))
        XCTAssertEqual(loaded.id, detail.id)
        XCTAssertEqual(updatedID, VaultObjectID("note"))
        let createCallCount = await create.callCount()
        let updateCallCount = await update.callCount()
        let detailCallCount = await detailLoader.callCount()
        XCTAssertEqual(createCallCount, 1)
        XCTAssertEqual(updateCallCount, 1)
        XCTAssertEqual(detailCallCount, 1)
    }

    func testIdentityApplicationServiceCreateUpdateLoad() async throws {
        let detail = makeDetail(type: .identity)
        let create = IdentityCreateSpy(result: .success(VaultObjectID("identity")))
        let update = IdentityUpdateSpy(result: .success(VaultObjectID("identity")))
        let detailLoader = DetailSpy(result: .success(detail))
        let mutation = ObjectMutationSpy()
        let service = IdentityApplicationService(
            createUseCase: create,
            updateUseCase: update,
            detailUseCase: detailLoader,
            moveToTrashUseCase: mutation,
            restoreUseCase: mutation
        )

        let createdID = try await service.createIdentity(IdentityEditorViewData(title: "Passport"))
        let loaded = try await service.loadIdentity(id: detail.id)
        let updatedID = try await service.updateIdentity(existing: detail, data: IdentityEditorViewData(title: "PAN"))

        XCTAssertEqual(createdID, VaultObjectID("identity"))
        XCTAssertEqual(loaded.type, .identity)
        XCTAssertEqual(updatedID, VaultObjectID("identity"))
        let createCallCount = await create.callCount()
        let updateCallCount = await update.callCount()
        let detailCallCount = await detailLoader.callCount()
        XCTAssertEqual(createCallCount, 1)
        XCTAssertEqual(updateCallCount, 1)
        XCTAssertEqual(detailCallCount, 1)
    }

    func testCardApplicationServiceCreateUpdateLoad() async throws {
        let detail = makeDetail(type: .card)
        let create = CardCreateSpy(result: .success(VaultObjectID("card")))
        let update = CardUpdateSpy(result: .success(VaultObjectID("card")))
        let detailLoader = DetailSpy(result: .success(detail))
        let mutation = ObjectMutationSpy()
        let service = CardApplicationService(
            createUseCase: create,
            updateUseCase: update,
            detailUseCase: detailLoader,
            moveToTrashUseCase: mutation,
            restoreUseCase: mutation
        )

        let createdID = try await service.createCard(CardEditorViewData(title: "Travel Card"))
        let loaded = try await service.loadCard(id: detail.id)
        let updatedID = try await service.updateCard(existing: detail, data: CardEditorViewData(title: "Updated"))

        XCTAssertEqual(createdID, VaultObjectID("card"))
        XCTAssertEqual(loaded.type, .card)
        XCTAssertEqual(updatedID, VaultObjectID("card"))
        let createCallCount = await create.callCount()
        let updateCallCount = await update.callCount()
        let detailCallCount = await detailLoader.callCount()
        XCTAssertEqual(createCallCount, 1)
        XCTAssertEqual(updateCallCount, 1)
        XCTAssertEqual(detailCallCount, 1)
    }

    func testDocumentApplicationServiceImportLoadThumbnail() async throws {
        let detail = makeDetail(type: .document)
        let documentImport = DocumentImportSpy(result: .success(VaultObjectID("document")))
        let detailLoader = DetailSpy(result: .success(detail))
        let thumbnail = ThumbnailSpy()
        let mutation = ObjectMutationSpy()
        let service = DocumentApplicationService(
            importUseCase: documentImport,
            detailUseCase: detailLoader,
            thumbnailUseCase: thumbnail,
            moveToTrashUseCase: mutation,
            restoreUseCase: mutation
        )

        let fileURL = URL(fileURLWithPath: "/tmp/report.pdf")
        let importedID = try await service.importDocument(fileURL: fileURL, vaultID: VaultID("vault"))
        let loaded = try await service.loadDocument(id: detail.id)
        let loadedThumbnail = try await service.loadThumbnail(objectId: detail.id)

        XCTAssertEqual(importedID, VaultObjectID("document"))
        XCTAssertEqual(loaded.type, .document)
        XCTAssertEqual(loadedThumbnail.objectId, detail.id)
        let importCallCount = await documentImport.callCount()
        let detailCallCount = await detailLoader.callCount()
        let thumbnailCallCount = await thumbnail.callCount()
        XCTAssertEqual(importCallCount, 1)
        XCTAssertEqual(detailCallCount, 1)
        XCTAssertEqual(thumbnailCallCount, 1)
    }

    func testTrashApplicationServiceListRestoreDeletePurge() async throws {
        let summary = VaultObjectSummary(
            id: VaultObjectID("trash"),
            type: .document,
            title: "Old",
            updatedAt: Date(),
            isDeleted: true
        )
        let list = TrashListSpy(result: .success([summary]))
        let mutation = ObjectMutationSpy()
        let purge = PurgeSpy()
        let service = TrashApplicationService(
            listUseCase: list,
            restoreUseCase: mutation,
            purgeUseCase: purge,
            permanentlyDeleteUseCase: mutation
        )

        let items = try await service.listTrash()
        try await service.restore(id: summary.id)
        try await service.permanentlyDelete(id: summary.id)
        try await service.purgeExpired()

        XCTAssertEqual(items.map { $0.id }, [summary.id])
        let receivedIDs = await mutation.receivedIDs()
        let purgeCallCount = await purge.callCount()
        XCTAssertEqual(receivedIDs, [summary.id, summary.id])
        XCTAssertEqual(purgeCallCount, 1)
    }

    func testRefactoredViewModelsDependOnServicesNotUseCases() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewModelPaths = [
            "Presentation/SecureNoteEditor/SecureNoteEditorViewModel.swift",
            "Presentation/IdentityEditor/IdentityEditorViewModel.swift",
            "Presentation/CardEditor/CardEditorViewModel.swift",
            "Presentation/ImportDocument/DocumentImportViewModel.swift",
            "Presentation/Trash/TrashViewModel.swift"
        ]

        for path in viewModelPaths {
            let source = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
            XCTAssertTrue(source.contains("ApplicationServicing"), "\(path) should depend on an application service.")
            XCTAssertFalse(source.contains("UseCase"), "\(path) should not reference use cases directly.")
            XCTAssertFalse(source.contains("VaultEngine"), "\(path) should not reference VaultEngine directly.")
            XCTAssertFalse(source.contains("StorageEngine"), "\(path) should not reference storage internals.")
            XCTAssertFalse(source.contains("CryptoEngine"), "\(path) should not reference crypto internals.")
            XCTAssertFalse(source.contains("BlobStore"), "\(path) should not reference blob internals.")
        }
    }

    func testApplicationServicesDoNotImportSwiftUIOrInfrastructureInternals() throws {
        let servicesRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Application/Services", isDirectory: true)
        let enumerator = try XCTUnwrap(
            FileManager.default.enumerator(at: servicesRoot, includingPropertiesForKeys: nil)
        )

        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            XCTAssertFalse(source.contains("import SwiftUI"), "\(fileURL.lastPathComponent) imports SwiftUI.")
            XCTAssertFalse(source.contains("StorageEngine"), "\(fileURL.lastPathComponent) references storage internals.")
            XCTAssertFalse(source.contains("CryptoEngine"), "\(fileURL.lastPathComponent) references crypto internals.")
            XCTAssertFalse(source.contains("BlobStore"), "\(fileURL.lastPathComponent) references blob internals.")
            XCTAssertFalse(source.contains("Repository"), "\(fileURL.lastPathComponent) references repositories.")
        }
    }

    private func makeDetail(type: VaultObjectType) -> VaultObjectDetail {
        VaultObjectDetail(
            id: VaultObjectID("\(type.rawValue)-detail"),
            type: type,
            metadata: VaultMetadata(title: "Detail"),
            payload: VaultPayload(notes: "Body")
        )
    }
}

private actor SecureNoteCreateSpy: CreateSecureNoteUsing {
    private let result: Result<VaultObjectID, Error>
    private var calls = 0

    init(result: Result<VaultObjectID, Error>) { self.result = result }

    func execute(data: SecureNoteEditorViewData) async throws -> VaultObjectID {
        calls += 1
        return try result.get()
    }

    func callCount() -> Int { calls }
}

private actor SecureNoteUpdateSpy: UpdateSecureNoteUsing {
    private let result: Result<VaultObjectID, Error>
    private var calls = 0

    init(result: Result<VaultObjectID, Error>) { self.result = result }

    func execute(existing: VaultObjectDetail, data: SecureNoteEditorViewData) async throws -> VaultObjectID {
        calls += 1
        return try result.get()
    }

    func callCount() -> Int { calls }
}

private actor IdentityCreateSpy: CreateIdentityUsing {
    private let result: Result<VaultObjectID, Error>
    private var calls = 0

    init(result: Result<VaultObjectID, Error>) { self.result = result }

    func execute(data: IdentityEditorViewData) async throws -> VaultObjectID {
        calls += 1
        return try result.get()
    }

    func callCount() -> Int { calls }
}

private actor IdentityUpdateSpy: UpdateIdentityUsing {
    private let result: Result<VaultObjectID, Error>
    private var calls = 0

    init(result: Result<VaultObjectID, Error>) { self.result = result }

    func execute(existing: VaultObjectDetail, data: IdentityEditorViewData) async throws -> VaultObjectID {
        calls += 1
        return try result.get()
    }

    func callCount() -> Int { calls }
}

private actor CardCreateSpy: CreateCardUsing {
    private let result: Result<VaultObjectID, Error>
    private var calls = 0

    init(result: Result<VaultObjectID, Error>) { self.result = result }

    func execute(data: CardEditorViewData) async throws -> VaultObjectID {
        calls += 1
        return try result.get()
    }

    func callCount() -> Int { calls }
}

private actor CardUpdateSpy: UpdateCardUsing {
    private let result: Result<VaultObjectID, Error>
    private var calls = 0

    init(result: Result<VaultObjectID, Error>) { self.result = result }

    func execute(existing: VaultObjectDetail, data: CardEditorViewData) async throws -> VaultObjectID {
        calls += 1
        return try result.get()
    }

    func callCount() -> Int { calls }
}

private actor DetailSpy: GetObjectDetailUsing {
    private let result: Result<VaultObjectDetail, Error>
    private var calls = 0

    init(result: Result<VaultObjectDetail, Error>) { self.result = result }

    func execute(id: VaultObjectID) async throws -> VaultObjectDetail {
        calls += 1
        return try result.get()
    }

    func callCount() -> Int { calls }
}

private actor ObjectMutationSpy: MoveObjectToTrashUsing, RestoreFromTrashUsing, PermanentlyDeleteObjectUsing {
    private var ids: [VaultObjectID] = []

    func execute(id: VaultObjectID) async throws {
        ids.append(id)
    }

    func receivedIDs() -> [VaultObjectID] { ids }
}

private actor DocumentImportSpy: ImportDocumentUsing {
    private let result: Result<VaultObjectID, Error>
    private var calls = 0

    init(result: Result<VaultObjectID, Error>) { self.result = result }

    func inspect(fileURL: URL) async throws -> DocumentImportFileInfo {
        DocumentImportFileInfo(fileName: fileURL.lastPathComponent, contentType: "application/pdf", originalSizeBytes: 1)
    }

    func execute(fileURL: URL, vaultID: VaultID) async throws -> VaultObjectID {
        calls += 1
        return try result.get()
    }

    func callCount() -> Int { calls }
}

private actor ThumbnailSpy: LoadThumbnailUsing {
    private var calls = 0

    func execute(objectId: VaultObjectID) async throws -> VaultThumbnail {
        calls += 1
        return VaultThumbnail(objectId: objectId, data: Data(), contentType: "image/png")
    }

    func callCount() -> Int { calls }
}

private actor TrashListSpy: ListTrashObjectsUsing {
    private let result: Result<[VaultObjectSummary], Error>

    init(result: Result<[VaultObjectSummary], Error>) { self.result = result }

    func execute() async throws -> [VaultObjectSummary] {
        try result.get()
    }
}

private actor PurgeSpy: PurgeTrashUsing {
    private var calls = 0

    func execute() async throws {
        calls += 1
    }

    func callCount() -> Int { calls }
}
