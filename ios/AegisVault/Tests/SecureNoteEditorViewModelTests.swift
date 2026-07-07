import SecureVaultKit
import XCTest
@testable import AegisVault

@MainActor
final class SecureNoteEditorViewModelTests: XCTestCase {
    func testInitialStateIsIdle() {
        XCTAssertEqual(makeViewModel().state, .idle)
    }

    func testCreateSecureNoteSaveSuccessRoutesToDetail() async {
        let objectID = VaultObjectID("note")
        let service = NoteService(createResult: .success(objectID))
        let viewModel = makeViewModel(service: service)
        await viewModel.prepare(mode: .create(VaultID("vault")))
        viewModel.setTitle("Trip checklist")
        viewModel.setContent("Passport and tickets")
        viewModel.setTagsInput("travel, important")

        await viewModel.save()

        XCTAssertEqual(viewModel.state, .saved(objectID))
        XCTAssertEqual(viewModel.route, .objectDetail(objectID))
        let received = await service.receivedData()
        XCTAssertEqual(received?.title, "Trip checklist")
        XCTAssertEqual(received?.content, "Passport and tickets")
        XCTAssertEqual(received?.tags, ["travel", "important"])
    }

    func testSaveRequiresTitle() async {
        let viewModel = makeViewModel(
            service: NoteService(createResult: .failure(ApplicationServiceError.validation(.missingTitle)))
        )
        await viewModel.prepare(mode: .create(VaultID("vault")))

        await viewModel.save()

        XCTAssertEqual(viewModel.state, .failed("Title is required."))
    }

    func testLockedSaveUsesSafeMessage() async {
        let viewModel = makeViewModel(
            service: NoteService(createResult: .failure(VaultError.locked))
        )
        await viewModel.prepare(mode: .create(VaultID("vault")))
        viewModel.setTitle("Note")
        viewModel.setContent("Content")

        await viewModel.save()

        XCTAssertEqual(viewModel.state, .failed("Your vault is locked."))
    }

    private func makeViewModel(
        service: NoteService = NoteService(createResult: .success(VaultObjectID("note")))
    ) -> SecureNoteEditorViewModel {
        SecureNoteEditorViewModel(secureNoteService: service)
    }
}

private actor NoteService: SecureNoteApplicationServicing {
    let createResult: Result<VaultObjectID, Error>
    private var data: SecureNoteEditorViewData?

    init(createResult: Result<VaultObjectID, Error>) {
        self.createResult = createResult
    }

    func createNote(_ data: SecureNoteEditorViewData) async throws -> VaultObjectID {
        self.data = data
        return try createResult.get()
    }

    func updateNote(existing: VaultObjectDetail, data: SecureNoteEditorViewData) async throws -> VaultObjectID {
        existing.id
    }

    func loadNote(id: VaultObjectID) async throws -> VaultObjectDetail {
        VaultObjectDetail(
            id: id,
            type: .secureNote,
            metadata: VaultMetadata(title: "Note"),
            payload: VaultPayload(notes: "Content")
        )
    }

    func moveToTrash(id: VaultObjectID) async throws {}

    func restore(id: VaultObjectID) async throws {}

    func receivedData() -> SecureNoteEditorViewData? {
        data
    }
}
