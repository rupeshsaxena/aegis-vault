import XCTest
import SecureVaultKit
@testable import AegisVault

final class UseCaseTests: XCTestCase {
    func testUseCasesCallVaultEngineMock() async throws {
        let engine = MockVaultEngine()
        let vaultID = try await CreateVaultUseCase(vaultEngine: engine).execute(
            name: "Personal",
            deviceID: DeviceID("device"),
            unlockMethod: .passphrase
        )
        try await UnlockVaultUseCase(vaultEngine: engine).execute(method: .passkey)
        _ = try await ListVaultObjectsUseCase(vaultEngine: engine).execute()
        let searchFilter = VaultObjectFilter(types: [.document])
        _ = try await SearchVaultUseCase(vaultEngine: engine).execute(
            query: "passport",
            filter: searchFilter
        )
        await LockVaultUseCase(vaultEngine: engine).execute(vaultID: vaultID)

        let calls = await engine.calls()
        XCTAssertEqual(calls, [.create, .unlock, .list, .search, .lock])
        let receivedSearchFilter = await engine.receivedSearchFilter()
        XCTAssertEqual(receivedSearchFilter, searchFilter)
    }

    func testListVaultObjectsUseCaseCallsVaultEngine() async throws {
        let engine = MockVaultEngine()
        let filter = VaultObjectFilter(types: [.photo])

        _ = try await ListVaultObjectsUseCase(vaultEngine: engine).execute(filter: filter)

        let receivedFilter = await engine.receivedListFilter()
        XCTAssertEqual(receivedFilter, filter)
    }

    func testSearchVaultUseCaseCallsVaultEngine() async throws {
        let engine = MockVaultEngine()
        let filter = VaultObjectFilter(types: [.identity])

        _ = try await SearchVaultUseCase(vaultEngine: engine).execute(
            query: "passport",
            filter: filter
        )

        let receivedFilter = await engine.receivedSearchFilter()
        XCTAssertEqual(receivedFilter, filter)
    }

    func testGetObjectDetailUseCaseCallsVaultEngine() async throws {
        let engine = MockVaultEngine()
        let objectID = VaultObjectID("detail")

        _ = try await GetObjectDetailUseCase(vaultEngine: engine).execute(id: objectID)

        let receivedID = await engine.receivedDetailID()
        XCTAssertEqual(receivedID, objectID)
    }

    func testMoveObjectToTrashUseCaseCallsVaultEngine() async throws {
        let engine = MockVaultEngine()
        let objectID = VaultObjectID("trash")

        try await MoveObjectToTrashUseCase(vaultEngine: engine).execute(id: objectID)

        let receivedID = await engine.receivedTrashID()
        XCTAssertEqual(receivedID, objectID)
    }

    func testCreateIdentityUseCaseMapsDraftAndCallsEngine() async throws {
        let engine = MockVaultEngine()
        let data = IdentityEditorViewData(
            title: "Passport",
            identityType: .passport,
            fullName: "Taylor Smith",
            documentNumber: "P123",
            notes: "Renew soon",
            tags: ["travel"]
        )

        _ = try await CreateIdentityUseCase(vaultEngine: engine).execute(data: data)

        let draft = await engine.receivedDraft()
        XCTAssertEqual(draft?.type, .identity)
        XCTAssertEqual(draft?.metadata.category, "passport")
        XCTAssertEqual(draft?.payload.fields["documentNumber"], .secureText("P123"))
        XCTAssertEqual(draft?.payload.notes, "Renew soon")
    }

    func testUpdateIdentityUseCaseMapsUpdateAndCallsEngine() async throws {
        let engine = MockVaultEngine()
        let detail = VaultObjectDetail(
            id: VaultObjectID("identity"),
            type: .identity,
            metadata: VaultMetadata(title: "Old", category: "other"),
            payload: VaultPayload(fields: ["legacy": .text("preserved")])
        )
        let data = IdentityEditorViewData(
            title: "PAN",
            identityType: .pan,
            fullName: "Taylor Smith",
            documentNumber: "ABCDE1234F"
        )

        _ = try await UpdateIdentityUseCase(vaultEngine: engine).execute(existing: detail, data: data)

        let update = await engine.receivedUpdate()
        XCTAssertEqual(update?.objectId, detail.id)
        XCTAssertEqual(update?.metadata?.category, "pan")
        XCTAssertEqual(update?.payload?.fields["documentNumber"], .secureText("ABCDE1234F"))
        XCTAssertEqual(update?.payload?.fields["legacy"], .text("preserved"))
    }

    func testCreateCardUseCaseMapsDraftAndCallsEngine() async throws {
        let engine = MockVaultEngine()
        let data = CardEditorViewData(
            title: "Travel Card",
            cardType: .creditCard,
            cardholderName: "Taylor Smith",
            cardNumber: "4111",
            expiryMonth: 12,
            expiryYear: 2030,
            issuer: "Example Bank",
            notes: "Primary card",
            tags: ["travel"]
        )

        _ = try await CreateCardUseCase(vaultEngine: engine).execute(data: data)

        let draft = await engine.receivedDraft()
        XCTAssertEqual(draft?.type, .card)
        XCTAssertEqual(draft?.metadata.category, "creditCard")
        XCTAssertEqual(draft?.payload.fields["cardNumber"], .secureText("4111"))
        XCTAssertEqual(draft?.payload.notes, "Primary card")
    }

    func testUpdateCardUseCaseMapsUpdateAndCallsEngine() async throws {
        let engine = MockVaultEngine()
        let detail = VaultObjectDetail(
            id: VaultObjectID("card"),
            type: .card,
            metadata: VaultMetadata(title: "Old", category: "other"),
            payload: VaultPayload(fields: ["legacy": .text("preserved")])
        )
        let data = CardEditorViewData(
            title: "Debit Card",
            cardType: .debitCard,
            cardholderName: "Taylor Smith",
            cardNumber: "5555"
        )

        _ = try await UpdateCardUseCase(vaultEngine: engine).execute(existing: detail, data: data)

        let update = await engine.receivedUpdate()
        XCTAssertEqual(update?.objectId, detail.id)
        XCTAssertEqual(update?.metadata?.category, "debitCard")
        XCTAssertEqual(update?.payload?.fields["cardNumber"], .secureText("5555"))
        XCTAssertEqual(update?.payload?.fields["legacy"], .text("preserved"))
    }

    func testViewModelsDoNotReferenceSecureVaultKitInternals() throws {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let presentationDirectory = testsDirectory.deletingLastPathComponent()
            .appendingPathComponent("Presentation", isDirectory: true)
        let forbiddenSymbols = [
            "StorageEngine",
            "CryptoEngine",
            "BlobStore",
            "Repository",
            "SQLite"
        ]
        let enumerator = try XCTUnwrap(
            FileManager.default.enumerator(
                at: presentationDirectory,
                includingPropertiesForKeys: nil
            )
        )

        for case let fileURL as URL in enumerator where fileURL.lastPathComponent.hasSuffix("ViewModel.swift") {
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            for symbol in forbiddenSymbols {
                XCTAssertFalse(source.contains(symbol), "\(fileURL.lastPathComponent) references \(symbol)")
            }
        }
    }

    func testUnlockVaultUseCaseCallsEngineWithSupportedPlaceholderMethods() async throws {
        let engine = MockVaultEngine()
        let useCase = UnlockVaultUseCase(vaultEngine: engine)

        try await useCase.execute(method: .biometric)
        try await useCase.execute(method: .passkey)
        try await useCase.execute(method: .recoverySecret("placeholder"))

        let methods = await engine.receivedUnlockMethods()
        XCTAssertEqual(methods, [.biometric, .passkey, .recoverySecret("placeholder")])
    }
}

private actor MockVaultEngine: VaultEngine {
    enum Call: Equatable {
        case create
        case unlock
        case list
        case search
        case detail
        case trash
        case createObject
        case updateObject
        case lock
    }

    private let vaultID = VaultID("mock-vault")
    private var recordedCalls: [Call] = []
    private var unlockMethods: [UnlockMethod] = []
    private var listFilter: VaultObjectFilter?
    private var searchFilter: VaultObjectFilter?
    private var detailID: VaultObjectID?
    private var trashID: VaultObjectID?
    private var draft: VaultObjectDraft?
    private var update: VaultObjectUpdate?

    func calls() -> [Call] { recordedCalls }
    func receivedUnlockMethods() -> [UnlockMethod] { unlockMethods }
    func receivedListFilter() -> VaultObjectFilter? { listFilter }
    func receivedSearchFilter() -> VaultObjectFilter? { searchFilter }
    func receivedDetailID() -> VaultObjectID? { detailID }
    func receivedTrashID() -> VaultObjectID? { trashID }
    func receivedDraft() -> VaultObjectDraft? { draft }
    func receivedUpdate() -> VaultObjectUpdate? { update }
    func runtimeStatus() async throws -> VaultRuntimeStatus { .locked(vaultID) }

    func createVault(config: VaultCreationConfig) async throws -> VaultID {
        recordedCalls.append(.create)
        return vaultID
    }

    func unlockVault(id: VaultID, using method: UnlockMethod) async throws {
        recordedCalls.append(.unlock)
        unlockMethods.append(method)
    }

    func unlockVault(method: UnlockMethod) async throws {
        recordedCalls.append(.unlock)
        unlockMethods.append(method)
    }

    func lockVault(id: VaultID) async {
        recordedCalls.append(.lock)
    }

    func lockVault() async {
        recordedCalls.append(.lock)
    }

    func createObject(_ draft: VaultObjectDraft) async throws -> VaultObjectID {
        recordedCalls.append(.createObject)
        self.draft = draft
        return VaultObjectID("created-object")
    }

    func createObject(_ draft: VaultObjectDraft, in vaultID: VaultID) async throws -> VaultObjectDetail {
        throw TestEngineError.unimplemented
    }

    func listObjects(filter: VaultObjectFilter) async throws -> [VaultObjectSummary] {
        recordedCalls.append(.list)
        listFilter = filter
        return []
    }

    func searchObjects(query: String) async throws -> [VaultObjectSummary] {
        recordedCalls.append(.search)
        return []
    }

    func searchObjects(
        query: String,
        filter: VaultObjectFilter
    ) async throws -> [VaultObjectSummary] {
        recordedCalls.append(.search)
        searchFilter = filter
        return []
    }

    func getObjectDetail(id: VaultObjectID) async throws -> VaultObjectDetail {
        recordedCalls.append(.detail)
        detailID = id
        return VaultObjectDetail(
            id: id,
            type: .secureNote,
            metadata: VaultMetadata(title: "Detail"),
            payload: VaultPayload()
        )
    }

    func updateObject(_ update: VaultObjectUpdate) async throws -> VaultObjectDetail {
        recordedCalls.append(.updateObject)
        self.update = update
        return VaultObjectDetail(
            id: update.objectId ?? VaultObjectID("updated-object"),
            type: .identity,
            metadata: update.metadata ?? VaultMetadata(title: "Updated"),
            payload: update.payload ?? VaultPayload()
        )
    }

    func updateObject(id: VaultObjectID, with update: VaultObjectUpdate) async throws -> VaultObjectDetail {
        throw TestEngineError.unimplemented
    }

    func objectDetail(id: VaultObjectID) async throws -> VaultObjectDetail {
        throw TestEngineError.unimplemented
    }

    func objectSummaries(
        in vaultID: VaultID,
        matching filter: VaultObjectFilter
    ) async throws -> [VaultObjectSummary] {
        []
    }

    func moveToTrash(_ id: VaultObjectID) async throws {
        recordedCalls.append(.trash)
        trashID = id
    }
    func restoreFromTrash(_ id: VaultObjectID) async throws {}
    func purgeTrash() async throws {}

    func importDocument(
        _ input: DocumentImportInput,
        into vaultID: VaultID
    ) async throws -> DocumentImportResult {
        throw TestEngineError.unimplemented
    }

    func moveObjectToTrash(id: VaultObjectID) async throws {}
}

private enum TestEngineError: Error {
    case unimplemented
}
