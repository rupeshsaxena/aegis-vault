import Foundation
import SecureVaultKit
import XCTest
@testable import AegisVault

@MainActor
final class ObjectDetailViewModelTests: XCTestCase {
    func testInitialStateIsIdle() {
        let viewModel = makeViewModel()

        XCTAssertEqual(viewModel.state, .idle)
    }

    func testLoadObjectSuccessShowsLoadedState() async {
        let detail = makeDetail()
        let viewModel = makeViewModel(detailResult: .success(detail))

        await viewModel.loadObject(id: detail.id)

        guard case .loaded(let viewData) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(viewData.id, detail.id)
        XCTAssertEqual(viewData.title, "Passport")
        XCTAssertEqual(viewData.type, .identity)
        XCTAssertEqual(viewData.attachments.count, 1)
        XCTAssertEqual(viewData.version, 3)
    }

    func testLoadObjectFailureShowsFailedState() async {
        let viewModel = makeViewModel(detailResult: .failure(DetailTestError.expected))

        await viewModel.loadObject(id: VaultObjectID("missing"))

        XCTAssertEqual(viewModel.state, .failed("Unable to load this item."))
    }

    func testSecureTextFieldsAreHiddenByDefault() async {
        let detail = makeDetail()
        let viewModel = makeViewModel(detailResult: .success(detail))

        await viewModel.loadObject(id: detail.id)

        guard case .loaded(let viewData) = viewModel.state,
              let password = viewData.fields.first(where: { $0.id == "password" }) else {
            return XCTFail("Expected password field")
        }
        XCTAssertTrue(password.isSensitive)
        XCTAssertFalse(password.isRevealed)
        XCTAssertEqual(password.value, "••••••••")
        XCTAssertNotEqual(password.value, "vault-secret")
    }

    func testRevealSecureTextTogglesVisibility() async {
        let detail = makeDetail()
        let viewModel = makeViewModel(detailResult: .success(detail))
        await viewModel.loadObject(id: detail.id)

        viewModel.toggleSecureField(id: "password")

        guard case .loaded(let revealedData) = viewModel.state,
              let revealed = revealedData.fields.first(where: { $0.id == "password" }) else {
            return XCTFail("Expected revealed password field")
        }
        XCTAssertTrue(revealed.isRevealed)
        XCTAssertEqual(revealed.value, "vault-secret")

        viewModel.toggleSecureField(id: "password")

        guard case .loaded(let hiddenData) = viewModel.state,
              let hidden = hiddenData.fields.first(where: { $0.id == "password" }) else {
            return XCTFail("Expected hidden password field")
        }
        XCTAssertFalse(hidden.isRevealed)
        XCTAssertEqual(hidden.value, "••••••••")
    }

    func testMoveToTrashSuccessMovesToTerminalState() async {
        let detail = makeDetail()
        let trashUseCase = MockMoveObjectToTrashUseCase(result: .success(()))
        let viewModel = makeViewModel(
            detailResult: .success(detail),
            trashUseCase: trashUseCase
        )
        await viewModel.loadObject(id: detail.id)

        await viewModel.moveToTrash()

        XCTAssertEqual(viewModel.state, .movedToTrash)
        let receivedID = await trashUseCase.receivedID()
        XCTAssertEqual(receivedID, detail.id)
    }

    func testMoveToTrashFailureShowsError() async {
        let detail = makeDetail()
        let viewModel = makeViewModel(
            detailResult: .success(detail),
            trashUseCase: MockMoveObjectToTrashUseCase(result: .failure(DetailTestError.expected))
        )
        await viewModel.loadObject(id: detail.id)

        await viewModel.moveToTrash()

        XCTAssertEqual(viewModel.state, .failed("Unable to move this item to Trash."))
    }

    func testEditRoutesToFutureObjectEditor() async {
        let detail = makeDetail()
        let viewModel = makeViewModel(detailResult: .success(detail))
        await viewModel.loadObject(id: detail.id)

        viewModel.edit()

        XCTAssertEqual(viewModel.route, .objectEditor(detail.id))
    }

    private func makeViewModel(
        detailResult: Result<VaultObjectDetail, Error>? = nil,
        trashUseCase: (any MoveObjectToTrashUsing)? = nil
    ) -> ObjectDetailViewModel {
        ObjectDetailViewModel(
            getObjectDetailUseCase: MockGetObjectDetailUseCase(
                result: detailResult ?? .success(makeDetail())
            ),
            moveObjectToTrashUseCase: trashUseCase
                ?? MockMoveObjectToTrashUseCase(result: .success(()))
        )
    }

    private func makeDetail() -> VaultObjectDetail {
        VaultObjectDetail(
            id: VaultObjectID("passport"),
            type: .identity,
            metadata: VaultMetadata(
                title: "Passport",
                subtitle: "Travel identity",
                tags: ["travel"],
                createdAt: Date(timeIntervalSince1970: 100),
                updatedAt: Date(timeIntervalSince1970: 200)
            ),
            payload: VaultPayload(
                fields: [
                    "country": .text("India"),
                    "password": .secureText("vault-secret")
                ],
                attachments: [
                    VaultAttachment(
                        id: BlobID("passport-file"),
                        role: .primary,
                        fileName: "passport.pdf",
                        contentType: "application/pdf",
                        byteCount: 512
                    )
                ]
            ),
            version: 3
        )
    }
}

private enum DetailTestError: Error {
    case expected
}

private actor MockGetObjectDetailUseCase: GetObjectDetailUsing {
    let result: Result<VaultObjectDetail, Error>

    init(result: Result<VaultObjectDetail, Error>) {
        self.result = result
    }

    func execute(id: VaultObjectID) async throws -> VaultObjectDetail {
        try result.get()
    }
}

private actor MockMoveObjectToTrashUseCase: MoveObjectToTrashUsing {
    let result: Result<Void, Error>
    private var objectID: VaultObjectID?

    init(result: Result<Void, Error>) {
        self.result = result
    }

    func execute(id: VaultObjectID) async throws {
        objectID = id
        try result.get()
    }

    func receivedID() -> VaultObjectID? { objectID }
}
