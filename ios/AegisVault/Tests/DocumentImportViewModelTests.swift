import Foundation
import SecureVaultKit
import XCTest
@testable import AegisVault

@MainActor
final class DocumentImportViewModelTests: XCTestCase {
    func testImportStartsLoadingState() async {
        let useCase = SuspendingImportDocumentUseCase()
        let viewModel = DocumentImportViewModel(importDocumentUseCase: useCase)
        await viewModel.handleFileSelection(.success([URL(fileURLWithPath: "/tmp/report.pdf")]))

        let task = Task { await viewModel.importSelectedFile(into: VaultID("vault")) }
        await useCase.waitUntilStarted()

        guard case .importing(let fileInfo, let progress) = viewModel.state else {
            return XCTFail("Expected importing state")
        }
        XCTAssertEqual(fileInfo.fileName, "report.pdf")
        XCTAssertGreaterThan(progress, 0)

        await useCase.succeed(with: VaultObjectID("document"))
        await task.value
    }

    func testImportSuccess() async {
        let objectID = VaultObjectID("document")
        let viewModel = DocumentImportViewModel(
            importDocumentUseCase: MockImportDocumentUseCase(result: .success(objectID))
        )
        await viewModel.handleFileSelection(.success([URL(fileURLWithPath: "/tmp/report.pdf")]))

        await viewModel.importSelectedFile(into: VaultID("vault"))

        XCTAssertEqual(viewModel.state, .imported(objectID))
        XCTAssertEqual(viewModel.route, .objectDetail(objectID))
    }

    func testImportFailure() async {
        let viewModel = DocumentImportViewModel(
            importDocumentUseCase: MockImportDocumentUseCase(
                result: .failure(DocumentImportTestError.expected)
            )
        )
        await viewModel.handleFileSelection(.success([URL(fileURLWithPath: "/tmp/report.pdf")]))

        await viewModel.importSelectedFile(into: VaultID("vault"))

        XCTAssertEqual(viewModel.state, .failed("Unable to import document."))
    }

    func testUnsupportedTypeFailure() async {
        let viewModel = DocumentImportViewModel(
            importDocumentUseCase: MockImportDocumentUseCase(
                inspectResult: .failure(VaultError.unsupportedOperation("Unsupported")),
                result: .success(VaultObjectID("unused"))
            )
        )

        await viewModel.handleFileSelection(.success([URL(fileURLWithPath: "/tmp/video.mp4")]))

        XCTAssertEqual(viewModel.state, .failed("This file type is not supported."))
    }
}

private enum DocumentImportTestError: Error {
    case expected
}

private actor MockImportDocumentUseCase: ImportDocumentUsing {
    private let inspectResult: Result<DocumentImportFileInfo, Error>
    private let result: Result<VaultObjectID, Error>

    init(
        inspectResult: Result<DocumentImportFileInfo, Error> = .success(
            DocumentImportFileInfo(
                fileName: "report.pdf",
                contentType: "application/pdf",
                originalSizeBytes: 1_024
            )
        ),
        result: Result<VaultObjectID, Error>
    ) {
        self.inspectResult = inspectResult
        self.result = result
    }

    func inspect(fileURL: URL) async throws -> DocumentImportFileInfo {
        try inspectResult.get()
    }

    func execute(fileURL: URL, vaultID: VaultID) async throws -> VaultObjectID {
        try result.get()
    }
}

private actor SuspendingImportDocumentUseCase: ImportDocumentUsing {
    private var started = false
    private var continuation: CheckedContinuation<VaultObjectID, Error>?

    func inspect(fileURL: URL) async throws -> DocumentImportFileInfo {
        DocumentImportFileInfo(
            fileName: fileURL.lastPathComponent,
            contentType: "application/pdf",
            originalSizeBytes: 1_024
        )
    }

    func execute(fileURL: URL, vaultID: VaultID) async throws -> VaultObjectID {
        started = true
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

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
