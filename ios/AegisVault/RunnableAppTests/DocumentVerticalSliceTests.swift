import XCTest
@testable import AegisVault
import SecureVaultKit

final class DocumentVerticalSliceTests: XCTestCase {
    func testPDFJPGAndPNGImportVerticalSlice() async throws {
        for fixture in [
            ("sample.pdf", "application/pdf"),
            ("sample.jpg", "image/jpeg"),
            ("sample.png", "image/png")
        ] {
            let engine = try await makeEngine()
            let vaultID = try await vaultID(from: engine)
            let url = try makeFile(name: fixture.0, bytes: 2_048)
            defer { try? FileManager.default.removeItem(at: url) }
            let clock = ContinuousClock()
            let start = clock.now

            let result = try await ImportDocumentUseCase(vaultEngine: engine).execute(
                fileURL: url,
                contentType: fixture.1,
                vaultID: vaultID
            )
            let duration = start.duration(to: clock.now)
            let detail = try await engine.getObjectDetail(id: result.objectId)
            let thumbnail = try await engine.loadThumbnail(for: result.objectId)

            XCTAssertEqual(detail.type, .document)
            XCTAssertEqual(result.metadata.byteCount, 2_048)
            XCTAssertFalse(result.attachments.isEmpty)
            XCTAssertNotNil(result.thumbnailAttachment)
            XCTAssertFalse(thumbnail.data.isEmpty)
            XCTAssertLessThan(duration, .seconds(5))
        }
    }

    func testImportedDocumentListsSearchesTrashesAndRestores() async throws {
        let engine = try await makeEngine()
        let vaultID = try await vaultID(from: engine)
        let url = try makeFile(name: "travel-document.pdf", bytes: 1_024)
        defer { try? FileManager.default.removeItem(at: url) }
        let result = try await ImportDocumentUseCase(vaultEngine: engine).execute(
            fileURL: url, contentType: "application/pdf", vaultID: vaultID
        )

        let documents = try await engine.listObjects(filter: VaultObjectFilter(types: [.document]))
        let search = try await engine.searchObjects(query: "travel", filter: VaultObjectFilter(types: [.document]))
        XCTAssertTrue(documents.contains { $0.id == result.objectId })
        XCTAssertTrue(search.contains { $0.id == result.objectId })

        try await engine.moveToTrash(result.objectId)
        let afterTrash = try await engine.listObjects(filter: VaultObjectFilter())
        let trash = try await engine.listObjects(filter: VaultObjectFilter(includeDeleted: true))
        XCTAssertFalse(afterTrash.contains { $0.id == result.objectId })
        XCTAssertTrue(trash.contains { $0.id == result.objectId && $0.isDeleted })

        try await engine.restoreFromTrash(result.objectId)
        let restored = try await engine.listObjects(filter: VaultObjectFilter())
        XCTAssertTrue(restored.contains { $0.id == result.objectId })
    }

    @MainActor
    func testDocumentImportViewModelSuccessAndFailure() async {
        let result = documentResult()
        let success = DocumentImportViewModel(importDocumentUseCase: ImportStub(result: .success(result)))
        success.select(URL(fileURLWithPath: "/tmp/sample.pdf"))
        await success.importSelected(into: VaultID())
        XCTAssertEqual(success.result?.objectId, result.objectId)
        XCTAssertEqual(success.progress, 1)

        let failure = DocumentImportViewModel(importDocumentUseCase: ImportStub(result: .failure(TestError.failed)))
        failure.select(URL(fileURLWithPath: "/tmp/sample.png"))
        await failure.importSelected(into: VaultID())
        XCTAssertNil(failure.result)
        XCTAssertEqual(failure.errorMessage, "Unable to import document.")
    }

    @MainActor
    func testVaultHomeDisplaysDocumentAndLoadsThumbnail() async {
        let summary = documentSummary()
        let viewModel = VaultHomeViewModel(
            listVaultObjectsUseCase: DocumentListStub(objects: [summary]),
            searchVaultObjectsUseCase: DocumentSearchStub(objects: [summary])
        )
        await viewModel.loadObjects()
        await viewModel.loadThumbnail(
            for: summary.id,
            using: ThumbnailStub(result: .success(VaultThumbnail(
                objectId: summary.id, data: Data("generated".utf8), contentType: "image/png"
            )))
        )
        XCTAssertEqual(viewModel.objects.map(\.type), [.document])
        XCTAssertNotNil(viewModel.thumbnails[summary.id])
    }

    @MainActor
    func testThumbnailFailureUsesSafePlaceholderState() async {
        let summary = documentSummary()
        let viewModel = VaultHomeViewModel(
            listVaultObjectsUseCase: DocumentListStub(objects: [summary]),
            searchVaultObjectsUseCase: DocumentSearchStub(objects: [summary])
        )
        await viewModel.loadThumbnail(for: summary.id, using: ThumbnailStub(result: .failure(TestError.failed)))
        XCTAssertNil(viewModel.thumbnails[summary.id])
        XCTAssertTrue(viewModel.missingThumbnails.contains(summary.id))
    }

    @MainActor
    func testObjectDetailLoadsDocumentMetadataAndThumbnail() async {
        let detail = documentDetail()
        let viewModel = ObjectDetailViewModel(
            objectID: detail.id,
            getDetailUseCase: DocumentDetailStub(detail: detail),
            moveToTrashUseCase: DocumentTrashStub(),
            loadThumbnailUseCase: ThumbnailStub(result: .success(VaultThumbnail(
                objectId: detail.id, data: Data("generated".utf8), contentType: "image/png"
            )))
        )
        await viewModel.loadDetail()
        XCTAssertEqual(viewModel.detail?.payload.fields["fileName"], .text("sample.pdf"))
        XCTAssertEqual(viewModel.detail?.payload.fields["contentType"], .text("application/pdf"))
        XCTAssertNotNil(viewModel.thumbnailData)
    }

    func testDocumentViewModelsDoNotAccessInfrastructure() throws {
        for file in ["DocumentImportView.swift", "VaultHomeView.swift", "ObjectDetailView.swift"] {
            let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("RunnableApp/\(file)")
            let source = try String(contentsOf: url, encoding: .utf8)
            XCTAssertFalse(source.contains("BlobStore"))
            XCTAssertFalse(source.contains("CryptoEngine"))
            XCTAssertFalse(source.contains("StorageEngine"))
        }
    }

    private func makeEngine() async throws -> any VaultEngine {
        let engine = VaultEngineFactory.makeSimulatorEngine()
        _ = try await engine.createVault(config: VaultCreationConfig(
            name: "Documents", deviceID: DeviceID(), unlockMethod: .passphrase
        ))
        return engine
    }

    private func vaultID(from engine: any VaultEngine) async throws -> VaultID {
        guard case .unlocked(let vaultID) = try await engine.runtimeStatus() else {
            throw TestError.failed
        }
        return vaultID
    }

    private func makeFile(name: String, bytes: Int) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID())-\(name)")
        try Data(repeating: 0x41, count: bytes).write(to: url, options: .atomic)
        return url
    }

    private func documentResult() -> DocumentImportResult {
        let attachment = VaultAttachment(
            id: BlobID(), role: .primary, fileName: "sample.pdf",
            contentType: "application/pdf", byteCount: 1_024
        )
        return DocumentImportResult(
            objectId: VaultObjectID(), attachment: attachment,
            metadata: ImportedDocumentMetadata(
                fileName: "sample.pdf", contentType: "application/pdf",
                byteCount: 1_024, fileExtension: "pdf"
            )
        )
    }

    private func documentSummary() -> VaultObjectSummary {
        VaultObjectSummary(id: VaultObjectID(), type: .document, title: "sample.pdf", updatedAt: Date())
    }

    private func documentDetail() -> VaultObjectDetail {
        let result = documentResult()
        return VaultObjectDetail(
            id: result.objectId,
            type: .document,
            metadata: VaultMetadata(title: "sample.pdf", subtitle: "application/pdf"),
            payload: VaultPayload(fields: [
                "fileName": .text("sample.pdf"),
                "contentType": .text("application/pdf"),
                "originalSizeBytes": .number(1_024)
            ], attachments: [result.attachment])
        )
    }
}

private enum TestError: Error { case failed }
private struct ImportStub: ImportDocumentUsing {
    let result: Result<DocumentImportResult, Error>
    func execute(fileURL: URL, contentType: String, vaultID: VaultID) async throws -> DocumentImportResult {
        try result.get()
    }
}
private struct DocumentListStub: ListVaultObjectsUsing {
    let objects: [VaultObjectSummary]
    func execute(filter: VaultObjectFilter) async throws -> [VaultObjectSummary] { objects }
}
private struct DocumentSearchStub: SearchVaultUsing {
    let objects: [VaultObjectSummary]
    func execute(query: String, filter: VaultObjectFilter) async throws -> [VaultObjectSummary] { objects }
}
private struct ThumbnailStub: LoadThumbnailUsing {
    let result: Result<VaultThumbnail, Error>
    func execute(objectId: VaultObjectID) async throws -> VaultThumbnail { try result.get() }
}
private struct DocumentDetailStub: GetObjectDetailUsing {
    let detail: VaultObjectDetail
    func execute(id: VaultObjectID) async throws -> VaultObjectDetail { detail }
}
private struct DocumentTrashStub: MoveObjectToTrashUsing {
    func execute(id: VaultObjectID) async throws {}
}
