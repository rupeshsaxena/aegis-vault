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
        let createUseCase = MockCreateIdentityUseCase(result: .success(objectID))
        let viewModel = makeViewModel(
            mode: .create(VaultID("vault")),
            createUseCase: createUseCase
        )
        viewModel.setTitle("Passport")
        viewModel.setDocumentNumber("P123")
        viewModel.setFullName("Taylor Smith")

        await viewModel.save()

        XCTAssertEqual(viewModel.state, .saved(objectID))
        XCTAssertEqual(viewModel.route, .objectDetail(objectID))
        let receivedData = await createUseCase.receivedData()
        XCTAssertEqual(receivedData?.documentNumber, "P123")
    }

    func testEditSaveCallsUpdateIdentityUseCase() async {
        let detail = makeIdentityDetail()
        let updateUseCase = MockUpdateIdentityUseCase(result: .success(detail.id))
        let viewModel = makeViewModel(
            mode: .edit(detail.id),
            detail: detail,
            updateUseCase: updateUseCase
        )
        await viewModel.prepare(mode: .edit(detail.id))
        viewModel.setTitle("Updated Passport")

        await viewModel.save()

        XCTAssertEqual(viewModel.state, .saved(detail.id))
        let receivedID = await updateUseCase.receivedExistingID()
        XCTAssertEqual(receivedID, detail.id)
    }

    func testFailureMapsToUserSafeError() async {
        let viewModel = makeViewModel(
            mode: .create(VaultID("vault")),
            createUseCase: MockCreateIdentityUseCase(result: .failure(VaultError.locked))
        )
        viewModel.setTitle("Passport")
        viewModel.setDocumentNumber("P123")

        await viewModel.save()

        XCTAssertEqual(viewModel.state, .failed("Your vault is locked."))
    }

    private func makeViewModel(
        mode: IdentityEditorMode,
        detail: VaultObjectDetail? = nil,
        createUseCase: (any CreateIdentityUsing)? = nil,
        updateUseCase: (any UpdateIdentityUsing)? = nil
    ) -> IdentityEditorViewModel {
        IdentityEditorViewModel(
            mode: mode,
            createIdentityUseCase: createUseCase
                ?? MockCreateIdentityUseCase(result: .success(VaultObjectID("created"))),
            updateIdentityUseCase: updateUseCase
                ?? MockUpdateIdentityUseCase(result: .success(VaultObjectID("updated"))),
            getObjectDetailUseCase: IdentityDetailLoader(
                result: detail.map(Result.success) ?? .failure(IdentityEditorTestError.missingDetail)
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

private actor MockCreateIdentityUseCase: CreateIdentityUsing {
    private let result: Result<VaultObjectID, Error>
    private var data: IdentityEditorViewData?

    init(result: Result<VaultObjectID, Error>) { self.result = result }

    func execute(data: IdentityEditorViewData) async throws -> VaultObjectID {
        self.data = data
        return try result.get()
    }

    func receivedData() -> IdentityEditorViewData? { data }
}

private actor MockUpdateIdentityUseCase: UpdateIdentityUsing {
    private let result: Result<VaultObjectID, Error>
    private var existingID: VaultObjectID?

    init(result: Result<VaultObjectID, Error>) { self.result = result }

    func execute(existing: VaultObjectDetail, data: IdentityEditorViewData) async throws -> VaultObjectID {
        existingID = existing.id
        return try result.get()
    }

    func receivedExistingID() -> VaultObjectID? { existingID }
}

private actor IdentityDetailLoader: GetObjectDetailUsing {
    private let result: Result<VaultObjectDetail, Error>

    init(result: Result<VaultObjectDetail, Error>) { self.result = result }

    func execute(id: VaultObjectID) async throws -> VaultObjectDetail {
        try result.get()
    }
}
