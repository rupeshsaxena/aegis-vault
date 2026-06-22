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
        let restore = TrashMutationUseCase(result: .success(()))
        let viewModel = makeViewModel(
            listResult: .success([summary]),
            restoreUseCase: restore
        )
        await viewModel.loadTrash()

        await viewModel.restore(id: summary.id)

        XCTAssertEqual(viewModel.state, .empty)
        let receivedIDs = await restore.receivedIDs()
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
            listResult: .success([summary]),
            restoreUseCase: TrashMutationUseCase(result: .failure(TrashTestError.expected))
        )
        await viewModel.loadTrash()

        await viewModel.restore(id: summary.id)

        XCTAssertEqual(viewModel.state, .failed("Unable to restore item."))
    }

    func testPermanentDeleteSuccessRemovesItem() async {
        let summary = makeDeletedSummary()
        let deletion = TrashMutationUseCase(result: .success(()))
        let viewModel = makeViewModel(
            listResult: .success([summary]),
            deleteUseCase: deletion
        )
        await viewModel.loadTrash()

        await viewModel.permanentlyDelete(id: summary.id)

        XCTAssertEqual(viewModel.state, .empty)
        let receivedIDs = await deletion.receivedIDs()
        XCTAssertEqual(receivedIDs, [summary.id])
    }

    func testPermanentDeleteFailureShowsUserSafeError() async {
        let summary = makeDeletedSummary()
        let viewModel = makeViewModel(
            listResult: .success([summary]),
            deleteUseCase: TrashMutationUseCase(result: .failure(TrashTestError.expected))
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
        listResult: Result<[VaultObjectSummary], Error> = .success([]),
        restoreUseCase: TrashMutationUseCase = TrashMutationUseCase(result: .success(())),
        deleteUseCase: TrashMutationUseCase = TrashMutationUseCase(result: .success(()))
    ) -> TrashViewModel {
        TrashViewModel(
            listTrashObjectsUseCase: TrashListUseCase(result: listResult),
            restoreFromTrashUseCase: restoreUseCase,
            purgeTrashUseCase: TrashPurgeUseCase(result: .success(())),
            permanentlyDeleteObjectUseCase: deleteUseCase
        )
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

private actor TrashListUseCase: ListTrashObjectsUsing {
    let result: Result<[VaultObjectSummary], Error>

    init(result: Result<[VaultObjectSummary], Error>) {
        self.result = result
    }

    func execute() async throws -> [VaultObjectSummary] {
        try result.get()
    }
}

private actor TrashMutationUseCase: RestoreFromTrashUsing, PermanentlyDeleteObjectUsing {
    let result: Result<Void, Error>
    private var ids: [VaultObjectID] = []

    init(result: Result<Void, Error>) {
        self.result = result
    }

    func execute(id: VaultObjectID) async throws {
        ids.append(id)
        try result.get()
    }

    func receivedIDs() -> [VaultObjectID] {
        ids
    }
}

private actor TrashPurgeUseCase: PurgeTrashUsing {
    let result: Result<Void, Error>

    init(result: Result<Void, Error>) {
        self.result = result
    }

    func execute() async throws {
        try result.get()
    }
}

private enum TrashTestError: Error {
    case expected
}
