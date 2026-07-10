import Foundation
import SecureVaultKit
import XCTest
@testable import AegisVault

@MainActor
final class PerformanceMemoryHardeningTests: XCTestCase {
    func testThumbnailRequestCoordinatorDeduplicatesConcurrentRequests() async throws {
        let coordinator = ThumbnailRequestCoordinator()
        let loader = CountingThumbnailLoader()
        let objectID = VaultObjectID("thumb")

        async let first = coordinator.thumbnail(for: objectID) {
            try await loader.load(objectID: objectID)
        }
        async let second = coordinator.thumbnail(for: objectID) {
            try await loader.load(objectID: objectID)
        }

        try await loader.waitUntilStarted()
        await loader.succeed()

        let thumbnails = try await [first, second]
        let callCount = await loader.callCount()
        let inFlightCount = await coordinator.inFlightCount()
        XCTAssertEqual(thumbnails.count, 2)
        XCTAssertEqual(callCount, 1)
        XCTAssertEqual(inFlightCount, 0)
    }

    func testVaultHomeLatestSearchResultWins() async throws {
        let latestSummary = VaultObjectSummary(
            id: VaultObjectID("latest"),
            type: .secureNote,
            title: "Latest",
            updatedAt: Date(timeIntervalSince1970: 1)
        )
        let searchUseCase = QueryAwareSearchUseCase(results: ["latest": [latestSummary]])
        let viewModel = VaultHomeViewModel(
            listVaultObjectsUseCase: StaticListUseCase(result: []),
            searchVaultUseCase: searchUseCase,
            lockVaultUseCase: NoopLockUseCase(),
            loadThumbnailUseCase: FailingThumbnailUseCase()
        )

        let oldTask = Task { await viewModel.search(query: "old") }
        try await Task.sleep(for: .milliseconds(100))
        let latestTask = Task { await viewModel.search(query: "latest") }
        await oldTask.value
        await latestTask.value

        guard case .loaded(let items) = viewModel.state else {
            return XCTFail("Expected latest search to load results")
        }
        XCTAssertEqual(items.map(\.title), ["Latest"])
        let queries = await searchUseCase.receivedQueries()
        XCTAssertEqual(queries, ["latest"])
    }

    func testVaultHomeEmptyQueryCancelsPendingSearch() async throws {
        let listSummary = VaultObjectSummary(
            id: VaultObjectID("list"),
            type: .secureNote,
            title: "Listed",
            updatedAt: Date(timeIntervalSince1970: 1)
        )
        let searchUseCase = QueryAwareSearchUseCase(results: ["old": []])
        let listUseCase = StaticListUseCase(result: [listSummary])
        let viewModel = VaultHomeViewModel(
            listVaultObjectsUseCase: listUseCase,
            searchVaultUseCase: searchUseCase,
            lockVaultUseCase: NoopLockUseCase(),
            loadThumbnailUseCase: FailingThumbnailUseCase()
        )

        let oldTask = Task { await viewModel.search(query: "old") }
        try await Task.sleep(for: .milliseconds(100))
        await viewModel.search(query: "")
        await oldTask.value

        guard case .loaded(let items) = viewModel.state else {
            return XCTFail("Expected list results after empty query")
        }
        XCTAssertEqual(items.map(\.title), ["Listed"])
        let queries = await searchUseCase.receivedQueries()
        let listCallCount = await listUseCase.callCount()
        XCTAssertEqual(queries, [])
        XCTAssertEqual(listCallCount, 1)
    }

    func testDocumentImportCancellationDoesNotPublishImportedState() async throws {
        let service = CancellableImportDocumentService()
        let viewModel = DocumentImportViewModel(documentService: service)
        let vaultID = VaultID("vault")

        await viewModel.handleFileSelection(.success([URL(fileURLWithPath: "/tmp/report.pdf")]))
        let importTask = Task { await viewModel.importSelectedFile(into: vaultID) }
        await waitForImportingState(viewModel)

        viewModel.cancel(vaultID: vaultID)
        await importTask.value

        XCTAssertEqual(viewModel.route, .vaultHome(vaultID))
        if case .imported = viewModel.state {
            XCTFail("Cancelled import must not publish an imported state")
        }
    }

    private func waitForImportingState(_ viewModel: DocumentImportViewModel) async {
        while true {
            if case .importing = viewModel.state {
                return
            }
            await Task.yield()
        }
    }
}

private actor CountingThumbnailLoader {
    private var calls = 0
    private var continuation: CheckedContinuation<Void, Never>?

    func load(objectID: VaultObjectID) async throws -> VaultThumbnail {
        calls += 1
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
        return VaultThumbnail(
            objectId: objectID,
            data: Data("thumbnail".utf8),
            contentType: "image/png"
        )
    }

    func waitUntilStarted() async throws {
        while calls == 0 {
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    func succeed() {
        continuation?.resume()
        continuation = nil
    }

    func callCount() -> Int {
        calls
    }
}

private actor QueryAwareSearchUseCase: SearchVaultUsing {
    private let results: [String: [VaultObjectSummary]]
    private var queries: [String] = []

    init(results: [String: [VaultObjectSummary]]) {
        self.results = results
    }

    func execute(query: String, filter: VaultObjectFilter) async throws -> [VaultObjectSummary] {
        queries.append(query)
        return results[query] ?? []
    }

    func receivedQueries() -> [String] {
        queries
    }
}

private actor StaticListUseCase: ListVaultObjectsUsing {
    private let result: [VaultObjectSummary]
    private var calls = 0

    init(result: [VaultObjectSummary]) {
        self.result = result
    }

    func execute(filter: VaultObjectFilter) async throws -> [VaultObjectSummary] {
        calls += 1
        return result
    }

    func callCount() -> Int {
        calls
    }
}

private actor NoopLockUseCase: LockVaultUsing {
    func execute(vaultID: VaultID) async {}
}

private actor FailingThumbnailUseCase: LoadThumbnailUsing {
    func execute(objectId: VaultObjectID) async throws -> VaultThumbnail {
        throw VaultError.thumbnailNotFound(objectId)
    }
}

private actor CancellableImportDocumentService: DocumentApplicationServicing {
    func inspectDocument(fileURL: URL) async throws -> DocumentImportFileInfo {
        DocumentImportFileInfo(
            fileName: fileURL.lastPathComponent,
            contentType: "application/pdf",
            originalSizeBytes: 1_024
        )
    }

    func importDocument(fileURL: URL, vaultID: VaultID) async throws -> VaultObjectID {
        try await Task.sleep(for: .seconds(10))
        return VaultObjectID("should-not-import")
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
