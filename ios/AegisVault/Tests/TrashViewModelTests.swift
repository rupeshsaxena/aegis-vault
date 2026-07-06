import Foundation
import SecureVaultKit
import XCTest
@testable import AegisVault

@MainActor
final class TrashViewModelTests: XCTestCase {
    func testInitialStateIsIdle() {
        XCTAssertEqual(makeViewModel().state, .idle)
    }

    func testLoadTrashSuccess() async {
        let summary = makeDeletedSummary()
        let viewModel = makeViewModel(listResult: .success([summary]))

        await viewModel.loadTrash()

        guard case .loaded(let items) = viewModel.state else {
            return XCTFail("Expected loaded Trash state.")
        }
        XCTAssertEqual(items.map(\.id), [summary.id])
        XCTAssertEqual(items.first?.deletedAt, summary.deletedAt)
        XCTAssertNotNil(items.first?.purgeAfter)
    }

    func testLoadTrashEmpty() async {
        let viewModel = makeViewModel(listResult: .success([]))

        await viewModel.loadTrash()

        XCTAssertEqual(viewModel.state, .empty)
    }

    func testLoadTrashFailure() async {
        let viewModel = makeViewModel(listResult: .failure(TrashTestError.expected))

        await viewModel.loadTrash()

        XCTAssertEqual(viewModel.state, .failed("Unable to load Trash."))
    }

    func testRestoreSuccessRemovesItemFromTrashState() async {
        let summary = makeDeletedSummary()
        let service = TrashService(listResult: .success([summary]))
        let viewModel = makeViewModel(service: service)
        await viewModel.loadTrash()

        await viewModel.restore(id: summary.id)

        XCTAssertEqual(viewModel.state, .empty)
        let receivedIDs = await service.receivedRestoreIDs()
        XCTAssertEqual(receivedIDs, [summary.id])
    }

    func testRestoreSuccessRoutesToVaultHomeWhenVaultIsProvided() async {
        let summary = makeDeletedSummary()
        let vaultID = VaultID("vault")
        let viewModel = makeViewModel(listResult: .success([summary]))
        await viewModel.loadTrash()

        await viewModel.restore(id: summary.id, vaultID: vaultID)

        XCTAssertEqual(viewModel.route, .vaultHome(vaultID))
    }

    func testRestoreFailureShowsUserSafeError() async {
        let summary = makeDeletedSummary()
        let viewModel = makeViewModel(
            service: TrashService(
                listResult: .success([summary]),
                restoreResult: .failure(TrashTestError.expected)
            )
        )
        await viewModel.loadTrash()

        await viewModel.restore(id: summary.id)

        XCTAssertEqual(viewModel.state, .failed("Unable to restore item."))
    }

    func testPermanentDeleteSuccessRemovesItem() async {
        let summary = makeDeletedSummary()
        let service = TrashService(listResult: .success([summary]))
        let viewModel = makeViewModel(service: service)
        await viewModel.loadTrash()

        await viewModel.permanentlyDelete(id: summary.id)

        XCTAssertEqual(viewModel.state, .empty)
        let receivedIDs = await service.receivedDeleteIDs()
        XCTAssertEqual(receivedIDs, [summary.id])
    }

    func testPermanentDeleteFailureShowsUserSafeError() async {
        let summary = makeDeletedSummary()
        let viewModel = makeViewModel(
            service: TrashService(
                listResult: .success([summary]),
                deleteResult: .failure(TrashTestError.expected)
            )
        )
        await viewModel.loadTrash()

        await viewModel.permanentlyDelete(id: summary.id)

        XCTAssertEqual(viewModel.state, .failed("Unable to permanently delete item."))
    }

    func testLockedErrorIsMappedSafely() async {
        let viewModel = makeViewModel(listResult: .failure(VaultError.locked))

        await viewModel.loadTrash()

        XCTAssertEqual(viewModel.state, .failed("Your vault is locked."))
    }

    func testViewModelSourceDoesNotDependOnInfrastructureServices() throws {
        let testsURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let sourceURL = testsURL
            .deletingLastPathComponent()
            .appendingPathComponent("Presentation/Trash/TrashViewModel.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertFalse(source.contains("StorageEngine"))
        XCTAssertFalse(source.contains("CryptoEngine"))
        XCTAssertFalse(source.contains("BlobStore"))
    }

    private func makeViewModel(
        listResult: Result<[VaultObjectSummary], Error> = .success([])
    ) -> TrashViewModel {
        makeViewModel(service: TrashService(listResult: listResult))
    }

    private func makeViewModel(service: TrashService) -> TrashViewModel {
        TrashViewModel(trashService: service)
    }

    private func makeDeletedSummary() -> VaultObjectSummary {
        let deletedAt = Date(timeIntervalSince1970: 1_700_000_000)
        return VaultObjectSummary(
            id: VaultObjectID("deleted"),
            type: .document,
            title: "Old document",
            updatedAt: deletedAt,
            isDeleted: true,
            deletedAt: deletedAt
        )
    }
}

private actor TrashService: TrashApplicationServicing {
    private let listResult: Result<[VaultObjectSummary], Error>
    private let restoreResult: Result<Void, Error>
    private let deleteResult: Result<Void, Error>
    private let purgeResult: Result<Void, Error>
    private var restoreIDs: [VaultObjectID] = []
    private var deleteIDs: [VaultObjectID] = []

    init(
        listResult: Result<[VaultObjectSummary], Error> = .success([]),
        restoreResult: Result<Void, Error> = .success(()),
        deleteResult: Result<Void, Error> = .success(()),
        purgeResult: Result<Void, Error> = .success(())
    ) {
        self.listResult = listResult
        self.restoreResult = restoreResult
        self.deleteResult = deleteResult
        self.purgeResult = purgeResult
    }

    func listTrash() async throws -> [VaultObjectSummary] {
        try listResult.get()
    }

    func restore(id: VaultObjectID) async throws {
        restoreIDs.append(id)
        try restoreResult.get()
    }

    func permanentlyDelete(id: VaultObjectID) async throws {
        deleteIDs.append(id)
        try deleteResult.get()
    }

    func purgeExpired() async throws {
        try purgeResult.get()
    }

    func receivedRestoreIDs() -> [VaultObjectID] {
        restoreIDs
    }

    func receivedDeleteIDs() -> [VaultObjectID] {
        deleteIDs
    }
}

private enum TrashTestError: Error {
    case expected
}
