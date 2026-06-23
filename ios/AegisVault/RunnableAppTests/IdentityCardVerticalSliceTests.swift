import XCTest
@testable import AegisVault
import SecureVaultKit

final class IdentityCardVerticalSliceTests: XCTestCase {
    func testIdentityCreateReadEditTrashRestoreFlow() async throws {
        let engine = try await makeEngine()
        let create = CreateIdentityUseCase(vaultEngine: engine)
        let update = UpdateIdentityUseCase(vaultEngine: engine)
        let objectID = try await create.execute(data: identityData())

        var detail = try await engine.getObjectDetail(id: objectID)
        XCTAssertEqual(detail.type, .identity)
        XCTAssertEqual(detail.metadata.category, IdentityDocumentType.passport.rawValue)
        XCTAssertEqual(detail.payload.fields["documentNumber"], .secureText("P1234567"))

        var edited = identityData()
        edited.title = "Updated Passport"
        _ = try await update.execute(existing: detail, data: edited)
        detail = try await engine.getObjectDetail(id: objectID)
        XCTAssertEqual(detail.metadata.title, "Updated Passport")

        try await engine.moveToTrash(objectID)
        let afterTrash = try await engine.listObjects(filter: VaultObjectFilter())
        XCTAssertFalse(afterTrash.contains { $0.id == objectID })
        try await engine.restoreFromTrash(objectID)
        let afterRestore = try await engine.listObjects(filter: VaultObjectFilter())
        XCTAssertTrue(afterRestore.contains { $0.id == objectID })
    }

    func testCardCreateReadEditTrashRestoreFlow() async throws {
        let engine = try await makeEngine()
        let create = CreateCardUseCase(vaultEngine: engine)
        let update = UpdateCardUseCase(vaultEngine: engine)
        let objectID = try await create.execute(data: cardData())

        var detail = try await engine.getObjectDetail(id: objectID)
        XCTAssertEqual(detail.type, .card)
        XCTAssertEqual(detail.metadata.category, CardType.creditCard.rawValue)
        XCTAssertEqual(detail.payload.fields["cardNumber"], .secureText("4111111111111111"))

        var edited = cardData()
        edited.title = "Updated Travel Card"
        _ = try await update.execute(existing: detail, data: edited)
        detail = try await engine.getObjectDetail(id: objectID)
        XCTAssertEqual(detail.metadata.title, "Updated Travel Card")

        try await engine.moveToTrash(objectID)
        let afterTrash = try await engine.listObjects(filter: VaultObjectFilter())
        XCTAssertFalse(afterTrash.contains { $0.id == objectID })
        try await engine.restoreFromTrash(objectID)
        let afterRestore = try await engine.listObjects(filter: VaultObjectFilter())
        XCTAssertTrue(afterRestore.contains { $0.id == objectID })
    }

    func testHomeFiltersAndSearchFindIdentityAndCard() async throws {
        let engine = try await makeEngine()
        _ = try await CreateIdentityUseCase(vaultEngine: engine).execute(data: identityData())
        _ = try await CreateCardUseCase(vaultEngine: engine).execute(data: cardData())

        let identities = try await engine.listObjects(filter: VaultObjectFilter(types: [.identity]))
        let cards = try await engine.listObjects(filter: VaultObjectFilter(types: [.card]))
        let titleResults = try await engine.searchObjects(query: "passport", filter: VaultObjectFilter())
        let tagResults = try await engine.searchObjects(query: "finance", filter: VaultObjectFilter())

        XCTAssertEqual(identities.map(\.type), [.identity])
        XCTAssertEqual(cards.map(\.type), [.card])
        XCTAssertEqual(titleResults.map(\.type), [.identity])
        XCTAssertEqual(tagResults.map(\.type), [.card])
    }

    @MainActor
    func testIdentityEditorCreateAndEditSuccess() async {
        let objectID = VaultObjectID()
        let create = IdentityCreateStub(result: objectID)
        let update = IdentityUpdateStub(result: objectID)
        let createViewModel = IdentityEditorViewModel(mode: .create, createUseCase: create, updateUseCase: update)
        createViewModel.data = identityData()
        await createViewModel.save()
        XCTAssertEqual(createViewModel.savedObjectID, objectID)

        let detail = identityDetail(id: objectID)
        let editViewModel = IdentityEditorViewModel(mode: .edit(detail), createUseCase: create, updateUseCase: update)
        editViewModel.data.title = "Edited"
        await editViewModel.save()
        XCTAssertEqual(editViewModel.savedObjectID, objectID)
    }

    @MainActor
    func testIdentityEditorValidatesTitleAndDocumentNumber() async {
        let stub = IdentityCreateStub(result: VaultObjectID())
        let viewModel = IdentityEditorViewModel(mode: .create, createUseCase: stub, updateUseCase: IdentityUpdateStub(result: VaultObjectID()))
        await viewModel.save()
        XCTAssertEqual(viewModel.errorMessage, "Title is required.")
        viewModel.data.title = "Passport"
        await viewModel.save()
        XCTAssertEqual(viewModel.errorMessage, "Document number is required.")
    }

    @MainActor
    func testCardEditorCreateAndEditSuccess() async {
        let objectID = VaultObjectID()
        let create = CardCreateStub(result: objectID)
        let update = CardUpdateStub(result: objectID)
        let createViewModel = CardEditorViewModel(mode: .create, createUseCase: create, updateUseCase: update)
        createViewModel.data = cardData()
        await createViewModel.save()
        XCTAssertEqual(createViewModel.savedObjectID, objectID)

        let detail = cardDetail(id: objectID)
        let editViewModel = CardEditorViewModel(mode: .edit(detail), createUseCase: create, updateUseCase: update)
        editViewModel.data.title = "Edited"
        await editViewModel.save()
        XCTAssertEqual(editViewModel.savedObjectID, objectID)
    }

    @MainActor
    func testCardEditorValidatesTitleAndCardNumber() async {
        let stub = CardCreateStub(result: VaultObjectID())
        let viewModel = CardEditorViewModel(mode: .create, createUseCase: stub, updateUseCase: CardUpdateStub(result: VaultObjectID()))
        await viewModel.save()
        XCTAssertEqual(viewModel.errorMessage, "Title is required.")
        viewModel.data.title = "Travel Card"
        await viewModel.save()
        XCTAssertEqual(viewModel.errorMessage, "Card number is required.")
    }

    @MainActor
    func testVaultHomeListsIdentityAndCard() async {
        let summaries = [identitySummary(), cardSummary()]
        let viewModel = VaultHomeViewModel(
            listVaultObjectsUseCase: ListStub(objects: summaries),
            searchVaultObjectsUseCase: SearchStub(objects: summaries)
        )
        await viewModel.loadObjects()
        XCTAssertEqual(Set(viewModel.objects.map(\.type)), Set([.identity, .card]))
    }

    @MainActor
    func testObjectDetailHidesAndRevealsSecureText() {
        let viewModel = ObjectDetailViewModel(
            objectID: VaultObjectID(),
            getDetailUseCase: DetailStub(detail: identityDetail()),
            moveToTrashUseCase: TrashStub()
        )
        let value = VaultFieldValue.secureText("P1234567")
        XCTAssertEqual(viewModel.displayedValue(for: "documentNumber", value: value), "••••••••")
        viewModel.toggleReveal(field: "documentNumber")
        XCTAssertEqual(viewModel.displayedValue(for: "documentNumber", value: value), "P1234567")
    }

    func testIdentityAndCardViewModelsRespectArchitectureBoundary() throws {
        for file in ["IdentityEditorView.swift", "CardEditorView.swift", "ObjectDetailView.swift", "VaultHomeView.swift"] {
            let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("RunnableApp/\(file)")
            let source = try String(contentsOf: url, encoding: .utf8)
            XCTAssertFalse(source.contains("StorageEngine"))
            XCTAssertFalse(source.contains("CryptoEngine"))
            XCTAssertFalse(source.contains("BlobStore"))
        }
    }

    private func makeEngine() async throws -> any VaultEngine {
        let engine = VaultEngineFactory.makeSimulatorEngine()
        _ = try await engine.createVault(config: VaultCreationConfig(
            name: "Vertical Slice", deviceID: DeviceID(), unlockMethod: .passphrase
        ))
        return engine
    }

    private func identityData() -> IdentityEditorViewData {
        IdentityEditorViewData(
            title: "Personal Passport", identityType: .passport, fullName: "Example User",
            documentNumber: "P1234567", notes: "", tags: ["travel"]
        )
    }

    private func cardData() -> CardEditorViewData {
        CardEditorViewData(
            title: "Travel Card", cardType: .creditCard, cardholderName: "Example User",
            cardNumber: "4111111111111111", issuer: "Example Bank", tags: ["finance"]
        )
    }

    private func identityDetail(id: VaultObjectID = VaultObjectID()) -> VaultObjectDetail {
        VaultObjectDetail(
            id: id, type: .identity,
            metadata: VaultMetadata(title: "Personal Passport", category: "passport"),
            payload: VaultPayload(fields: ["documentNumber": .secureText("P1234567")])
        )
    }

    private func cardDetail(id: VaultObjectID = VaultObjectID()) -> VaultObjectDetail {
        VaultObjectDetail(
            id: id, type: .card,
            metadata: VaultMetadata(title: "Travel Card", category: "creditCard"),
            payload: VaultPayload(fields: ["cardNumber": .secureText("4111111111111111")])
        )
    }

    private func identitySummary() -> VaultObjectSummary {
        VaultObjectSummary(id: VaultObjectID(), type: .identity, title: "Passport", updatedAt: Date())
    }

    private func cardSummary() -> VaultObjectSummary {
        VaultObjectSummary(id: VaultObjectID(), type: .card, title: "Card", updatedAt: Date())
    }
}

private struct IdentityCreateStub: CreateIdentityUsing {
    let result: VaultObjectID
    func execute(data: IdentityEditorViewData) async throws -> VaultObjectID { result }
}
private struct IdentityUpdateStub: UpdateIdentityUsing {
    let result: VaultObjectID
    func execute(existing: VaultObjectDetail, data: IdentityEditorViewData) async throws -> VaultObjectID { result }
}
private struct CardCreateStub: CreateCardUsing {
    let result: VaultObjectID
    func execute(data: CardEditorViewData) async throws -> VaultObjectID { result }
}
private struct CardUpdateStub: UpdateCardUsing {
    let result: VaultObjectID
    func execute(existing: VaultObjectDetail, data: CardEditorViewData) async throws -> VaultObjectID { result }
}
private struct ListStub: ListVaultObjectsUsing {
    let objects: [VaultObjectSummary]
    func execute(filter: VaultObjectFilter) async throws -> [VaultObjectSummary] { objects }
}
private struct SearchStub: SearchVaultUsing {
    let objects: [VaultObjectSummary]
    func execute(query: String, filter: VaultObjectFilter) async throws -> [VaultObjectSummary] { objects }
}
private struct DetailStub: GetObjectDetailUsing {
    let detail: VaultObjectDetail
    func execute(id: VaultObjectID) async throws -> VaultObjectDetail { detail }
}
private struct TrashStub: MoveObjectToTrashUsing {
    func execute(id: VaultObjectID) async throws {}
}
