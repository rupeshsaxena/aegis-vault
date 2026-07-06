import Foundation
import SecureVaultKit
import XCTest
@testable import AegisVault

@MainActor
final class IdentityEditorViewModelTests: XCTestCase {
    func testCreateModeInitialState() {
        let viewModel = makeViewModel(mode: .create(VaultID("vault")))

        XCTAssertEqual(viewModel.state, .editing)
        XCTAssertEqual(viewModel.data.identityType, .passport)
    }

    func testEditModeInitialStateLoadsExistingIdentity() async {
        let detail = makeIdentityDetail()
        let viewModel = makeViewModel(mode: .edit(detail.id), detail: detail)

        XCTAssertEqual(viewModel.state, .idle)
        await viewModel.prepare(mode: .edit(detail.id))

        XCTAssertEqual(viewModel.state, .editing)
        XCTAssertEqual(viewModel.data.title, "Passport")
        XCTAssertEqual(viewModel.data.documentNumber, "P123")
        XCTAssertEqual(viewModel.data.identityType, .passport)
    }

    func testSaveFailsWhenTitleIsEmpty() async {
        let viewModel = makeViewModel(mode: .create(VaultID("vault")))
        viewModel.setDocumentNumber("P123")

        await viewModel.save()

        XCTAssertEqual(viewModel.state, .failed("Title is required."))
    }

    func testSaveFailsWhenRequiredDocumentNumberIsEmpty() async {
        let viewModel = makeViewModel(mode: .create(VaultID("vault")))
        viewModel.setTitle("Passport")
        viewModel.setIdentityType(.passport)

        await viewModel.save()

        XCTAssertEqual(viewModel.state, .failed("Document number is required."))
    }

    func testCreateSaveCallsCreateIdentityUseCaseAndReturnsSavedID() async {
        let objectID = VaultObjectID("created")
        let service = MockIdentityService(createResult: .success(objectID))
        let viewModel = makeViewModel(
            mode: .create(VaultID("vault")),
            service: service
        )
        viewModel.setTitle("Passport")
        viewModel.setDocumentNumber("P123")
        viewModel.setFullName("Taylor Smith")

        await viewModel.save()

        XCTAssertEqual(viewModel.state, .saved(objectID))
        XCTAssertEqual(viewModel.route, .objectDetail(objectID))
        let receivedData = await service.receivedData()
        XCTAssertEqual(receivedData?.documentNumber, "P123")
    }

    func testEditSaveCallsUpdateIdentityUseCase() async {
        let detail = makeIdentityDetail()
        let service = MockIdentityService(
            detailResult: .success(detail),
            updateResult: .success(detail.id)
        )
        let viewModel = makeViewModel(
            mode: .edit(detail.id),
            service: service
        )
        await viewModel.prepare(mode: .edit(detail.id))
        viewModel.setTitle("Updated Passport")

        await viewModel.save()

        XCTAssertEqual(viewModel.state, .saved(detail.id))
        let receivedID = await service.receivedExistingID()
        XCTAssertEqual(receivedID, detail.id)
    }

    func testFailureMapsToUserSafeError() async {
        let viewModel = makeViewModel(
            mode: .create(VaultID("vault")),
            service: MockIdentityService(createResult: .failure(VaultError.locked))
        )
        viewModel.setTitle("Passport")
        viewModel.setDocumentNumber("P123")

        await viewModel.save()

        XCTAssertEqual(viewModel.state, .failed("Your vault is locked."))
    }

    private func makeViewModel(
        mode: IdentityEditorMode,
        detail: VaultObjectDetail? = nil,
        service: MockIdentityService? = nil
    ) -> IdentityEditorViewModel {
        IdentityEditorViewModel(
            mode: mode,
            identityService: service ?? MockIdentityService(
                detailResult: detail.map(Result.success) ?? .failure(IdentityEditorTestError.missingDetail)
            )
        )
    }

    private func makeIdentityDetail() -> VaultObjectDetail {
        VaultObjectDetail(
            id: VaultObjectID("identity"),
            type: .identity,
            metadata: VaultMetadata(title: "Passport", category: "passport", tags: ["travel"]),
            payload: VaultPayload(
                notes: "Renew soon",
                fields: [
                    "identityType": .text("passport"),
                    "fullName": .text("Taylor Smith"),
                    "documentNumber": .secureText("P123")
                ]
            )
        )
    }
}

private enum IdentityEditorTestError: Error {
    case missingDetail
}

private actor MockIdentityService: IdentityApplicationServicing {
    private let createResult: Result<VaultObjectID, Error>
    private let updateResult: Result<VaultObjectID, Error>
    private let detailResult: Result<VaultObjectDetail, Error>
    private var data: IdentityEditorViewData?
    private var existingID: VaultObjectID?

    init(
        createResult: Result<VaultObjectID, Error> = .success(VaultObjectID("created")),
        detailResult: Result<VaultObjectDetail, Error> = .failure(IdentityEditorTestError.missingDetail),
        updateResult: Result<VaultObjectID, Error> = .success(VaultObjectID("updated"))
    ) {
        self.createResult = createResult
        self.detailResult = detailResult
        self.updateResult = updateResult
    }

    func createIdentity(_ data: IdentityEditorViewData) async throws -> VaultObjectID {
        self.data = data
        return try createResult.get()
    }

    func updateIdentity(existing: VaultObjectDetail, data: IdentityEditorViewData) async throws -> VaultObjectID {
        existingID = existing.id
        return try updateResult.get()
    }

    func loadIdentity(id: VaultObjectID) async throws -> VaultObjectDetail { try detailResult.get() }

    func moveToTrash(id: VaultObjectID) async throws {}

    func restore(id: VaultObjectID) async throws {}

    func receivedData() -> IdentityEditorViewData? { data }

    func receivedExistingID() -> VaultObjectID? { existingID }
}
