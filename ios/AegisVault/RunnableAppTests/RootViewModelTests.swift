import XCTest
@testable import AegisVault
import SecureVaultKit

final class RootViewModelTests: XCTestCase {
    private static let stubVaultID: VaultID = "test-vault-id"

    // MARK: - RootViewModel

    @MainActor
    func testRoutesToOnboardingWhenNoVaultExists() async {
        let viewModel = makeViewModel(route: .onboarding)
        await viewModel.determineInitialRoute()
        XCTAssertEqual(viewModel.route, .onboarding)
    }

    @MainActor
    func testRoutesToUnlockWhenVaultExistsAndIsLocked() async {
        let viewModel = makeViewModel(route: .unlock(Self.stubVaultID))
        await viewModel.determineInitialRoute()
        XCTAssertEqual(viewModel.route, .unlock(Self.stubVaultID))
    }

    @MainActor
    func testRoutesToVaultHomeWhenVaultIsUnlocked() async {
        let viewModel = makeViewModel(route: .vaultHome(Self.stubVaultID))
        await viewModel.determineInitialRoute()
        XCTAssertEqual(viewModel.route, .vaultHome(Self.stubVaultID))
    }

    @MainActor
    func testAppContainerCreatesDependencies() async throws {
        let container = AppContainer()
        let status = try await container.vaultEngine.runtimeStatus()
        let viewModel = container.makeRootViewModel()
        XCTAssertEqual(status, .missing)
        XCTAssertNil(viewModel.route)
    }

    func testRootViewModelDoesNotReferenceInfrastructureEngines() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("RunnableApp/RootViewModel.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        XCTAssertFalse(source.contains("StorageEngine"))
        XCTAssertFalse(source.contains("CryptoEngine"))
        XCTAssertFalse(source.contains("BlobStore"))
        XCTAssertFalse(source.contains("import SecureVaultKit"))
    }

    @MainActor
    func testNavigateToRouteUpdatesViewModelRoute() {
        let viewModel = makeViewModel(route: .onboarding)
        viewModel.navigate(to: .vaultHome(Self.stubVaultID))
        XCTAssertEqual(viewModel.route, .vaultHome(Self.stubVaultID))
    }

    // MARK: - OnboardingViewModel

    @MainActor
    func testOnboardingViewModelCreateVaultSuccess() async {
        let vaultID = Self.stubVaultID
        let vm = OnboardingViewModel(createVaultUseCase: StubCreateVaultUseCase(result: .success(vaultID)))
        vm.vaultName = "My Vault"
        await vm.createVault()
        XCTAssertEqual(vm.createdVaultID, vaultID)
        XCTAssertNil(vm.errorMessage)
        XCTAssertFalse(vm.isCreating)
    }

    @MainActor
    func testOnboardingViewModelCreateVaultFailure() async {
        let vm = OnboardingViewModel(createVaultUseCase: StubCreateVaultUseCase(result: .failure(VaultError.vaultAlreadyExists)))
        vm.vaultName = "My Vault"
        await vm.createVault()
        XCTAssertNil(vm.createdVaultID)
        XCTAssertNotNil(vm.errorMessage)
    }

    @MainActor
    func testCompleteOnboardingSetsCompletedVaultID() async {
        let vaultID = Self.stubVaultID
        let vm = OnboardingViewModel(createVaultUseCase: StubCreateVaultUseCase(result: .success(vaultID)))
        vm.vaultName = "My Vault"
        await vm.createVault()
        vm.completeOnboarding()
        XCTAssertEqual(vm.completedVaultID, vaultID)
    }

    // MARK: - VaultHomeViewModel

    @MainActor
    func testVaultHomeViewModelEmptyState() async {
        let vm = VaultHomeViewModel(
            listVaultObjectsUseCase: StubListVaultObjectsUseCase(objects: []),
            searchVaultObjectsUseCase: StubSearchVaultObjectsUseCase(objects: [])
        )
        await vm.loadObjects()
        XCTAssertTrue(vm.isEmpty)
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
    }

    @MainActor
    func testVaultHomeViewModelTriggerRefreshIncrementsID() {
        let vm = VaultHomeViewModel(
            listVaultObjectsUseCase: StubListVaultObjectsUseCase(objects: []),
            searchVaultObjectsUseCase: StubSearchVaultObjectsUseCase(objects: [])
        )
        XCTAssertEqual(vm.refreshID, 0)
        vm.triggerRefresh()
        XCTAssertEqual(vm.refreshID, 1)
        vm.triggerRefresh()
        XCTAssertEqual(vm.refreshID, 2)
    }

    // MARK: - SecureNoteEditorViewModel

    @MainActor
    func testSecureNoteEditorViewModelCreateSuccess() async {
        let objectID = VaultObjectID()
        let vm = SecureNoteEditorViewModel(
            mode: .create,
            createUseCase: StubCreateSecureNoteUseCase(result: .success(objectID)),
            updateUseCase: StubUpdateSecureNoteUseCase(result: .success(()))
        )
        vm.title = "Test Note"
        vm.notes = "Some content"
        await vm.save()
        XCTAssertEqual(vm.savedObjectID, objectID)
        XCTAssertNil(vm.errorMessage)
        XCTAssertFalse(vm.isSaving)
    }

    @MainActor
    func testSecureNoteEditorViewModelEditSuccess() async {
        let detail = makeStubDetail()
        let vm = SecureNoteEditorViewModel(
            mode: .edit(detail),
            createUseCase: StubCreateSecureNoteUseCase(result: .success(VaultObjectID())),
            updateUseCase: StubUpdateSecureNoteUseCase(result: .success(()))
        )
        vm.title = "Updated Title"
        await vm.save()
        XCTAssertEqual(vm.savedObjectID, detail.id)
        XCTAssertNil(vm.errorMessage)
    }

    @MainActor
    func testSecureNoteEditorViewModelRejectsEmptyTitle() {
        let vm = SecureNoteEditorViewModel(
            mode: .create,
            createUseCase: StubCreateSecureNoteUseCase(result: .success(VaultObjectID())),
            updateUseCase: StubUpdateSecureNoteUseCase(result: .success(()))
        )
        vm.title = ""
        XCTAssertFalse(vm.canSave)
        vm.title = "   "
        XCTAssertFalse(vm.canSave)
    }

    @MainActor
    func testSecureNoteEditorViewModelPopulatesFieldsInEditMode() {
        let detail = makeStubDetail(title: "My Note", notes: "Body text")
        let vm = SecureNoteEditorViewModel(
            mode: .edit(detail),
            createUseCase: StubCreateSecureNoteUseCase(result: .success(VaultObjectID())),
            updateUseCase: StubUpdateSecureNoteUseCase(result: .success(()))
        )
        XCTAssertEqual(vm.title, "My Note")
        XCTAssertEqual(vm.notes, "Body text")
    }

    // MARK: - ObjectDetailViewModel

    @MainActor
    func testObjectDetailViewModelLoadsDetail() async {
        let detail = makeStubDetail()
        let vm = ObjectDetailViewModel(
            objectID: detail.id,
            getDetailUseCase: StubGetObjectDetailUseCase(result: .success(detail)),
            moveToTrashUseCase: StubMoveObjectToTrashUseCase(result: .success(()))
        )
        await vm.loadDetail()
        XCTAssertEqual(vm.detail?.metadata.title, "Test Note")
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
    }

    @MainActor
    func testObjectDetailViewModelMoveToTrashSuccess() async {
        let detail = makeStubDetail()
        let vm = ObjectDetailViewModel(
            objectID: detail.id,
            getDetailUseCase: StubGetObjectDetailUseCase(result: .success(detail)),
            moveToTrashUseCase: StubMoveObjectToTrashUseCase(result: .success(()))
        )
        await vm.moveToTrash()
        XCTAssertTrue(vm.isMovedToTrash)
        XCTAssertNil(vm.errorMessage)
    }

    // MARK: - TrashViewModel

    @MainActor
    func testTrashViewModelRestoreSuccess() async {
        let detail = makeStubDetail()
        let summary = VaultObjectSummary(
            id: detail.id, type: .secureNote, title: "Test Note",
            updatedAt: Date(), isDeleted: true, deletedAt: Date()
        )
        let vm = TrashViewModel(
            listObjectsUseCase: StubListVaultObjectsUseCase(objects: [summary]),
            restoreFromTrashUseCase: StubRestoreFromTrashUseCase(result: .success(()))
        )
        await vm.loadObjects()
        XCTAssertEqual(vm.objects.count, 1)
        await vm.restore(id: detail.id)
        XCTAssertTrue(vm.isEmpty)
        XCTAssertEqual(vm.objects.count, 0)
    }

    // MARK: - UseCase Integration Tests (via SimulatorVaultEngine)

    func testCreateSecureNoteUseCaseCreatesObject() async throws {
        let (engine, _) = try await makePrimedEngine()
        let useCase = CreateSecureNoteUseCase(vaultEngine: engine)
        let objectID = try await useCase.execute(title: "My Note", notes: "Content")
        let objects = try await engine.listObjects(filter: VaultObjectFilter())
        XCTAssertTrue(objects.contains { $0.id == objectID })
        XCTAssertEqual(objects.first { $0.id == objectID }?.title, "My Note")
    }

    func testGetObjectDetailUseCaseFetchesDetail() async throws {
        let (engine, _) = try await makePrimedEngine()
        let createUseCase = CreateSecureNoteUseCase(vaultEngine: engine)
        let objectID = try await createUseCase.execute(title: "Detail Test", notes: "body")
        let getUseCase = GetObjectDetailUseCase(vaultEngine: engine)
        let detail = try await getUseCase.execute(id: objectID)
        XCTAssertEqual(detail.metadata.title, "Detail Test")
        XCTAssertEqual(detail.payload.notes, "body")
    }

    func testUpdateSecureNoteUseCaseUpdatesTitle() async throws {
        let (engine, _) = try await makePrimedEngine()
        let createUseCase = CreateSecureNoteUseCase(vaultEngine: engine)
        let objectID = try await createUseCase.execute(title: "Original", notes: "initial content")
        let updateUseCase = UpdateSecureNoteUseCase(vaultEngine: engine)
        try await updateUseCase.execute(id: objectID, title: "Updated", notes: "new body")
        let detail = try await engine.getObjectDetail(id: objectID)
        XCTAssertEqual(detail.metadata.title, "Updated")
        XCTAssertEqual(detail.payload.notes, "new body")
    }

    func testMoveObjectToTrashUseCaseRemovesFromListing() async throws {
        let (engine, _) = try await makePrimedEngine()
        let createUseCase = CreateSecureNoteUseCase(vaultEngine: engine)
        let objectID = try await createUseCase.execute(title: "To Trash", notes: "test content")
        let trashUseCase = MoveObjectToTrashUseCase(vaultEngine: engine)
        try await trashUseCase.execute(id: objectID)
        let objects = try await engine.listObjects(filter: VaultObjectFilter())
        XCTAssertFalse(objects.contains { $0.id == objectID })
    }

    func testRestoreFromTrashUseCaseRestoresObject() async throws {
        let (engine, _) = try await makePrimedEngine()
        let createUseCase = CreateSecureNoteUseCase(vaultEngine: engine)
        let objectID = try await createUseCase.execute(title: "Restore Me", notes: "test content")
        try await engine.moveToTrash(objectID)
        let restoreUseCase = RestoreFromTrashUseCase(vaultEngine: engine)
        try await restoreUseCase.execute(id: objectID)
        let objects = try await engine.listObjects(filter: VaultObjectFilter())
        XCTAssertTrue(objects.contains { $0.id == objectID })
    }

    // MARK: - Architecture Tests

    func testViewModelsDoNotAccessInfrastructure() throws {
        let files = ["SecureNoteEditorView", "ObjectDetailView", "TrashView", "VaultHomeView"]
        for filename in files {
            let sourceURL = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("RunnableApp/\(filename).swift")
            let source = try String(contentsOf: sourceURL, encoding: .utf8)
            XCTAssertFalse(source.contains("StorageEngine"), "\(filename) references StorageEngine")
            XCTAssertFalse(source.contains("CryptoEngine"), "\(filename) references CryptoEngine")
            XCTAssertFalse(source.contains("BlobStore"), "\(filename) references BlobStore")
        }
    }

    // MARK: - Helpers

    @MainActor
    private func makeViewModel(route: RootRoute) -> RootViewModel {
        RootViewModel(resolveRootRouteUseCase: StubResolveRootRouteUseCase(route: route))
    }

    private func makePrimedEngine() async throws -> (any VaultEngine, VaultID) {
        let engine = VaultEngineFactory.makeSimulatorEngine()
        let vaultID = try await engine.createVault(config: VaultCreationConfig(
            name: "Test Vault",
            deviceID: DeviceID(),
            unlockMethod: .passphrase
        ))
        try await engine.unlockVault(method: .passphrase)
        return (engine, vaultID)
    }

    private func makeStubDetail(
        id: VaultObjectID = VaultObjectID(),
        title: String = "Test Note",
        notes: String? = "Content"
    ) -> VaultObjectDetail {
        VaultObjectDetail(
            id: id,
            type: .secureNote,
            metadata: VaultMetadata(title: title),
            payload: VaultPayload(notes: notes)
        )
    }
}

// MARK: - Stubs

private struct StubResolveRootRouteUseCase: ResolveRootRouteUsing {
    let route: RootRoute
    func execute() async throws -> RootRoute { route }
}

private struct StubCreateVaultUseCase: CreateVaultUsing {
    let result: Result<VaultID, Error>
    func execute(name: String, deviceID: DeviceID, unlockMethod: UnlockMethod) async throws -> VaultID {
        try result.get()
    }
}

private struct StubListVaultObjectsUseCase: ListVaultObjectsUsing {
    let objects: [VaultObjectSummary]
    func execute(filter: VaultObjectFilter) async throws -> [VaultObjectSummary] {
        objects
    }
}

private struct StubSearchVaultObjectsUseCase: SearchVaultObjectsUsing {
    let objects: [VaultObjectSummary]
    func execute(query: String, filter: VaultObjectFilter) async throws -> [VaultObjectSummary] {
        objects
    }
}

private struct StubCreateSecureNoteUseCase: CreateSecureNoteUsing {
    let result: Result<VaultObjectID, Error>
    func execute(title: String, notes: String?) async throws -> VaultObjectID {
        try result.get()
    }
}

private struct StubUpdateSecureNoteUseCase: UpdateSecureNoteUsing {
    let result: Result<Void, Error>
    func execute(id: VaultObjectID, title: String, notes: String?) async throws {
        _ = try result.get()
    }
}

private struct StubGetObjectDetailUseCase: GetObjectDetailUsing {
    let result: Result<VaultObjectDetail, Error>
    func execute(id: VaultObjectID) async throws -> VaultObjectDetail {
        try result.get()
    }
}

private struct StubMoveObjectToTrashUseCase: MoveObjectToTrashUsing {
    let result: Result<Void, Error>
    func execute(id: VaultObjectID) async throws {
        _ = try result.get()
    }
}

private struct StubRestoreFromTrashUseCase: RestoreFromTrashUsing {
    let result: Result<Void, Error>
    func execute(id: VaultObjectID) async throws {
        _ = try result.get()
    }
}
