import SecureVaultKit
import XCTest
@testable import AegisVault

@MainActor
final class CardEditorViewModelTests: XCTestCase {
    func testCreateModeInitialState() {
        let viewModel = makeViewModel(mode: .create(VaultID("vault")))

        XCTAssertEqual(viewModel.state, .editing)
        XCTAssertEqual(viewModel.data.cardType, .creditCard)
    }

    func testEditModeInitialStateLoadsExistingCard() async {
        let detail = makeCardDetail()
        let viewModel = makeViewModel(mode: .edit(detail.id), detail: detail)

        XCTAssertEqual(viewModel.state, .idle)
        await viewModel.prepare(mode: .edit(detail.id))

        XCTAssertEqual(viewModel.state, .editing)
        XCTAssertEqual(viewModel.data.title, "Travel Card")
        XCTAssertEqual(viewModel.data.cardNumber, "4111111111111111")
        XCTAssertEqual(viewModel.data.expiryMonth, 12)
    }

    func testSaveFailsWhenTitleIsEmpty() async {
        let viewModel = makeViewModel(mode: .create(VaultID("vault")))
        viewModel.setCardNumber("4111")

        await viewModel.save()

        XCTAssertEqual(viewModel.state, .failed("Title is required."))
    }

    func testSaveFailsWhenRequiredCardNumberIsEmpty() async {
        let viewModel = makeViewModel(mode: .create(VaultID("vault")))
        viewModel.setTitle("Travel Card")
        viewModel.setCardType(.creditCard)

        await viewModel.save()

        XCTAssertEqual(viewModel.state, .failed("Card number is required."))
    }

    func testCreateSaveCallsUseCaseAndReturnsSavedID() async {
        let objectID = VaultObjectID("created-card")
        let createUseCase = MockCreateCardUseCase(result: .success(objectID))
        let viewModel = makeViewModel(
            mode: .create(VaultID("vault")),
            createUseCase: createUseCase
        )
        viewModel.setTitle("Travel Card")
        viewModel.setCardNumber("4111")

        await viewModel.save()

        XCTAssertEqual(viewModel.state, .saved(objectID))
        XCTAssertEqual(viewModel.route, .objectDetail(objectID))
        let receivedData = await createUseCase.receivedData()
        XCTAssertEqual(receivedData?.cardNumber, "4111")
    }

    func testEditSaveCallsUpdateUseCase() async {
        let detail = makeCardDetail()
        let updateUseCase = MockUpdateCardUseCase(result: .success(detail.id))
        let viewModel = makeViewModel(
            mode: .edit(detail.id),
            detail: detail,
            updateUseCase: updateUseCase
        )
        await viewModel.prepare(mode: .edit(detail.id))
        viewModel.setTitle("Updated Card")

        await viewModel.save()

        XCTAssertEqual(viewModel.state, .saved(detail.id))
        let receivedID = await updateUseCase.receivedExistingID()
        XCTAssertEqual(receivedID, detail.id)
    }

    func testFailureMapsToUserSafeError() async {
        let viewModel = makeViewModel(
            mode: .create(VaultID("vault")),
            createUseCase: MockCreateCardUseCase(result: .failure(VaultError.locked))
        )
        viewModel.setTitle("Travel Card")
        viewModel.setCardNumber("4111")

        await viewModel.save()

        XCTAssertEqual(viewModel.state, .failed("Your vault is locked."))
    }

    private func makeViewModel(
        mode: CardEditorMode,
        detail: VaultObjectDetail? = nil,
        createUseCase: (any CreateCardUsing)? = nil,
        updateUseCase: (any UpdateCardUsing)? = nil
    ) -> CardEditorViewModel {
        CardEditorViewModel(
            mode: mode,
            createCardUseCase: createUseCase
                ?? MockCreateCardUseCase(result: .success(VaultObjectID("created"))),
            updateCardUseCase: updateUseCase
                ?? MockUpdateCardUseCase(result: .success(VaultObjectID("updated"))),
            getObjectDetailUseCase: CardDetailLoader(
                result: detail.map(Result.success) ?? .failure(CardEditorTestError.missingDetail)
            )
        )
    }

    private func makeCardDetail() -> VaultObjectDetail {
        VaultObjectDetail(
            id: VaultObjectID("card"),
            type: .card,
            metadata: VaultMetadata(title: "Travel Card", category: "creditCard"),
            payload: VaultPayload(
                notes: "Primary card",
                fields: [
                    "cardType": .text("creditCard"),
                    "cardholderName": .text("Taylor Smith"),
                    "cardNumber": .secureText("4111111111111111"),
                    "expiryMonth": .number(12),
                    "expiryYear": .number(2030),
                    "issuer": .text("Example Bank")
                ]
            )
        )
    }
}

private enum CardEditorTestError: Error {
    case missingDetail
}

private actor MockCreateCardUseCase: CreateCardUsing {
    private let result: Result<VaultObjectID, Error>
    private var data: CardEditorViewData?

    init(result: Result<VaultObjectID, Error>) { self.result = result }

    func execute(data: CardEditorViewData) async throws -> VaultObjectID {
        self.data = data
        return try result.get()
    }

    func receivedData() -> CardEditorViewData? { data }
}

private actor MockUpdateCardUseCase: UpdateCardUsing {
    private let result: Result<VaultObjectID, Error>
    private var existingID: VaultObjectID?

    init(result: Result<VaultObjectID, Error>) { self.result = result }

    func execute(existing: VaultObjectDetail, data: CardEditorViewData) async throws -> VaultObjectID {
        existingID = existing.id
        return try result.get()
    }

    func receivedExistingID() -> VaultObjectID? { existingID }
}

private actor CardDetailLoader: GetObjectDetailUsing {
    private let result: Result<VaultObjectDetail, Error>

    init(result: Result<VaultObjectDetail, Error>) { self.result = result }

    func execute(id: VaultObjectID) async throws -> VaultObjectDetail {
        try result.get()
    }
}
