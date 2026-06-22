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
        let createUseCase = NoteCreateUseCase(result: .success(objectID))
        let viewModel = makeViewModel(createUseCase: createUseCase)
        await viewModel.prepare(mode: .create(VaultID("vault")))
        viewModel.setTitle("Trip checklist")
        viewModel.setContent("Passport and tickets")
        viewModel.setTagsInput("travel, important")

        await viewModel.save()

        XCTAssertEqual(viewModel.state, .saved(objectID))
        XCTAssertEqual(viewModel.route, .objectDetail(objectID))
        let received = await createUseCase.receivedData()
        XCTAssertEqual(received?.title, "Trip checklist")
        XCTAssertEqual(received?.content, "Passport and tickets")
        XCTAssertEqual(received?.tags, ["travel", "important"])
    }

    func testSaveRequiresTitle() async {
        let viewModel = makeViewModel()
        await viewModel.prepare(mode: .create(VaultID("vault")))

        await viewModel.save()

        XCTAssertEqual(viewModel.state, .failed("Title is required."))
    }

    func testLockedSaveUsesSafeMessage() async {
        let viewModel = makeViewModel(
            createUseCase: NoteCreateUseCase(result: .failure(VaultError.locked))
        )
        await viewModel.prepare(mode: .create(VaultID("vault")))
        viewModel.setTitle("Note")
        viewModel.setContent("Content")

        await viewModel.save()

        XCTAssertEqual(viewModel.state, .failed("Your vault is locked."))
    }

    private func makeViewModel(
        createUseCase: NoteCreateUseCase = NoteCreateUseCase(
            result: .success(VaultObjectID("note"))
        )
    ) -> SecureNoteEditorViewModel {
        SecureNoteEditorViewModel(
            createSecureNoteUseCase: createUseCase,
            updateSecureNoteUseCase: NoteUpdateUseCase(),
            getObjectDetailUseCase: NoteDetailUseCase()
        )
    }
}

private actor NoteCreateUseCase: CreateSecureNoteUsing {
    let result: Result<VaultObjectID, Error>
    private var data: SecureNoteEditorViewData?

    init(result: Result<VaultObjectID, Error>) {
        self.result = result
    }

    func execute(data: SecureNoteEditorViewData) async throws -> VaultObjectID {
        self.data = data
        return try result.get()
    }

    func receivedData() -> SecureNoteEditorViewData? {
        data
    }
}

private actor NoteUpdateUseCase: UpdateSecureNoteUsing {
    func execute(existing: VaultObjectDetail, data: SecureNoteEditorViewData) async throws -> VaultObjectID {
        existing.id
    }
}

private actor NoteDetailUseCase: GetObjectDetailUsing {
    func execute(id: VaultObjectID) async throws -> VaultObjectDetail {
        VaultObjectDetail(
            id: id,
            type: .secureNote,
            metadata: VaultMetadata(title: "Note"),
            payload: VaultPayload(notes: "Content")
        )
    }
}
