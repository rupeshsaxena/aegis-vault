import Foundation
import SecureVaultKit
import XCTest
@testable import AegisVault

@MainActor
final class DocumentImportViewModelTests: XCTestCase {
    func testImportStartsLoadingState() async {
        let service = SuspendingDocumentService()
        let viewModel = DocumentImportViewModel(documentService: service)
        await viewModel.handleFileSelection(.success([URL(fileURLWithPath: "/tmp/report.pdf")]))

        let task = Task { await viewModel.importSelectedFile(into: VaultID("vault")) }
        await service.waitUntilStarted()

        guard case .importing(let fileInfo, let progress) = viewModel.state else {
            return XCTFail("Expected importing state")
        }
        XCTAssertEqual(fileInfo.fileName, "report.pdf")
        XCTAssertGreaterThan(progress, 0)

        await service.succeed(with: VaultObjectID("document"))
        await task.value
    }

    func testImportSuccess() async {
        let objectID = VaultObjectID("document")
        let viewModel = DocumentImportViewModel(
            documentService: MockDocumentService(importResult: .success(objectID))
        )
        await viewModel.handleFileSelection(.success([URL(fileURLWithPath: "/tmp/report.pdf")]))

        await viewModel.importSelectedFile(into: VaultID("vault"))

        XCTAssertEqual(viewModel.state, .imported(objectID))
        XCTAssertEqual(viewModel.route, .objectDetail(objectID))
    }

    func testImportFailure() async {
        let viewModel = DocumentImportViewModel(
            documentService: MockDocumentService(
                importResult: .failure(DocumentImportTestError.expected)
            )
        )
        await viewModel.handleFileSelection(.success([URL(fileURLWithPath: "/tmp/report.pdf")]))

        await viewModel.importSelectedFile(into: VaultID("vault"))

        XCTAssertEqual(viewModel.state, .failed("Unable to import document."))
    }

    func testUnsupportedTypeFailure() async {
        let viewModel = DocumentImportViewModel(
            documentService: MockDocumentService(
                inspectResult: .failure(VaultError.unsupportedOperation("Unsupported")),
                importResult: .success(VaultObjectID("unused"))
            )
        )

        await viewModel.handleFileSelection(.success([URL(fileURLWithPath: "/tmp/video.mp4")]))

        XCTAssertEqual(viewModel.state, .failed("This file type is not supported."))
    }
}

private enum DocumentImportTestError: Error {
    case expected
}

private actor MockDocumentService: DocumentApplicationServicing {
    private let inspectResult: Result<DocumentImportFileInfo, Error>
    private let importResult: Result<VaultObjectID, Error>

    init(
        inspectResult: Result<DocumentImportFileInfo, Error> = .success(
            DocumentImportFileInfo(
                fileName: "report.pdf",
                contentType: "application/pdf",
                originalSizeBytes: 1_024
            )
        ),
        importResult: Result<VaultObjectID, Error>
    ) {
        self.inspectResult = inspectResult
        self.importResult = importResult
    }

    func inspectDocument(fileURL: URL) async throws -> DocumentImportFileInfo {
        try inspectResult.get()
    }

    func importDocument(fileURL: URL, vaultID: VaultID) async throws -> VaultObjectID {
        try importResult.get()
    }

    func loadDocument(id: VaultObjectID) async throws -> VaultObjectDetail {
        VaultObjectDetail(
            id: id,
            type: .document,
            metadata: VaultMetadata(title: "Document"),
            payload: VaultPayload()
        )
    }

    func loadThumbnail(objectId: VaultObjectID) async throws -> VaultThumbnail {
        VaultThumbnail(objectId: objectId, data: Data(), contentType: "image/png")
    }

    func moveToTrash(id: VaultObjectID) async throws {}

    func restore(id: VaultObjectID) async throws {}
}

private actor SuspendingDocumentService: DocumentApplicationServicing {
    private var started = false
    private var continuation: CheckedContinuation<VaultObjectID, Error>?

    func inspectDocument(fileURL: URL) async throws -> DocumentImportFileInfo {
        DocumentImportFileInfo(
            fileName: fileURL.lastPathComponent,
            contentType: "application/pdf",
            originalSizeBytes: 1_024
        )
    }

    func importDocument(fileURL: URL, vaultID: VaultID) async throws -> VaultObjectID {
        started = true
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func loadDocument(id: VaultObjectID) async throws -> VaultObjectDetail {
        VaultObjectDetail(
            id: id,
            type: .document,
            metadata: VaultMetadata(title: "Document"),
            payload: VaultPayload()
        )
    }

    func loadThumbnail(objectId: VaultObjectID) async throws -> VaultThumbnail {
        VaultThumbnail(objectId: objectId, data: Data(), contentType: "image/png")
    }

    func moveToTrash(id: VaultObjectID) async throws {}

    func restore(id: VaultObjectID) async throws {}

    func waitUntilStarted() async {
        while !started {
            await Task.yield()
        }
    }

    func succeed(with objectID: VaultObjectID) {
        continuation?.resume(returning: objectID)
        continuation = nil
    }
}
