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
        let viewModel = makeViewModel(
            mode: .create(VaultID("vault")),
            service: MockCardService(createResult: .failure(ApplicationServiceError.validation(.missingTitle)))
        )
        viewModel.setCardNumber("4111")

        await viewModel.save()

        XCTAssertEqual(viewModel.state, .failed("Title is required."))
    }

    func testSaveFailsWhenRequiredCardNumberIsEmpty() async {
        let viewModel = makeViewModel(
            mode: .create(VaultID("vault")),
            service: MockCardService(
                createResult: .failure(ApplicationServiceError.validation(.missingRequiredField("cardNumber")))
            )
        )
        viewModel.setTitle("Travel Card")
        viewModel.setCardType(.creditCard)

        await viewModel.save()

        XCTAssertEqual(viewModel.state, .failed("Card number is required."))
    }

    func testCreateSaveCallsUseCaseAndReturnsSavedID() async {
        let objectID = VaultObjectID("created-card")
        let service = MockCardService(createResult: .success(objectID))
        let viewModel = makeViewModel(
            mode: .create(VaultID("vault")),
            service: service
        )
        viewModel.setTitle("Travel Card")
        viewModel.setCardNumber("4111")

        await viewModel.save()

        XCTAssertEqual(viewModel.state, .saved(objectID))
        XCTAssertEqual(viewModel.route, .objectDetail(objectID))
        let receivedData = await service.receivedData()
        XCTAssertEqual(receivedData?.cardNumber, "4111")
    }

    func testEditSaveCallsUpdateUseCase() async {
        let detail = makeCardDetail()
        let service = MockCardService(
            detailResult: .success(detail),
            updateResult: .success(detail.id)
        )
        let viewModel = makeViewModel(
            mode: .edit(detail.id),
            service: service
        )
        await viewModel.prepare(mode: .edit(detail.id))
        viewModel.setTitle("Updated Card")

        await viewModel.save()

        XCTAssertEqual(viewModel.state, .saved(detail.id))
        let receivedID = await service.receivedExistingID()
        XCTAssertEqual(receivedID, detail.id)
    }

    func testFailureMapsToUserSafeError() async {
        let viewModel = makeViewModel(
            mode: .create(VaultID("vault")),
            service: MockCardService(createResult: .failure(VaultError.locked))
        )
        viewModel.setTitle("Travel Card")
        viewModel.setCardNumber("4111")

        await viewModel.save()

        XCTAssertEqual(viewModel.state, .failed("Your vault is locked."))
    }

    private func makeViewModel(
        mode: CardEditorMode,
        detail: VaultObjectDetail? = nil,
        service: MockCardService? = nil
    ) -> CardEditorViewModel {
        CardEditorViewModel(
            mode: mode,
            cardService: service ?? MockCardService(
                detailResult: detail.map(Result.success) ?? .failure(CardEditorTestError.missingDetail)
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

private actor MockCardService: CardApplicationServicing {
    private let createResult: Result<VaultObjectID, Error>
    private let updateResult: Result<VaultObjectID, Error>
    private let detailResult: Result<VaultObjectDetail, Error>
    private var data: CardEditorViewData?
    private var existingID: VaultObjectID?

    init(
        createResult: Result<VaultObjectID, Error> = .success(VaultObjectID("created")),
        detailResult: Result<VaultObjectDetail, Error> = .failure(CardEditorTestError.missingDetail),
        updateResult: Result<VaultObjectID, Error> = .success(VaultObjectID("updated"))
    ) {
        self.createResult = createResult
        self.detailResult = detailResult
        self.updateResult = updateResult
    }

    func createCard(_ data: CardEditorViewData) async throws -> VaultObjectID {
        self.data = data
        return try createResult.get()
    }

    func updateCard(existing: VaultObjectDetail, data: CardEditorViewData) async throws -> VaultObjectID {
        existingID = existing.id
        return try updateResult.get()
    }

    func loadCard(id: VaultObjectID) async throws -> VaultObjectDetail { try detailResult.get() }

    func moveToTrash(id: VaultObjectID) async throws {}

    func restore(id: VaultObjectID) async throws {}

    func receivedData() -> CardEditorViewData? { data }

    func receivedExistingID() -> VaultObjectID? { existingID }
}
