import SecureVaultKit

protocol CardApplicationServicing: Sendable {
    func createCard(_ data: CardEditorViewData) async throws -> VaultObjectID
    func updateCard(existing: VaultObjectDetail, data: CardEditorViewData) async throws -> VaultObjectID
    func loadCard(id: VaultObjectID) async throws -> VaultObjectDetail
    func moveToTrash(id: VaultObjectID) async throws
    func restore(id: VaultObjectID) async throws
}

struct CardApplicationService: CardApplicationServicing {
    private let createUseCase: any CreateCardUsing
    private let updateUseCase: any UpdateCardUsing
    private let detailUseCase: any GetObjectDetailUsing
    private let moveToTrashUseCase: any MoveObjectToTrashUsing
    private let restoreUseCase: any RestoreFromTrashUsing
    private let validator: CardValidator

    init(
        createUseCase: any CreateCardUsing,
        updateUseCase: any UpdateCardUsing,
        detailUseCase: any GetObjectDetailUsing,
        moveToTrashUseCase: any MoveObjectToTrashUsing,
        restoreUseCase: any RestoreFromTrashUsing,
        validator: CardValidator = CardValidator()
    ) {
        self.createUseCase = createUseCase
        self.updateUseCase = updateUseCase
        self.detailUseCase = detailUseCase
        self.moveToTrashUseCase = moveToTrashUseCase
        self.restoreUseCase = restoreUseCase
        self.validator = validator
    }

    func createCard(_ data: CardEditorViewData) async throws -> VaultObjectID {
        try validate(CardAggregate(data: data))
        return try await createUseCase.execute(data: data)
    }

    func updateCard(existing: VaultObjectDetail, data: CardEditorViewData) async throws -> VaultObjectID {
        try validate(CardAggregate(data: data))
        return try await updateUseCase.execute(existing: existing, data: data)
    }

    func loadCard(id: VaultObjectID) async throws -> VaultObjectDetail {
        try await detailUseCase.execute(id: id)
    }

    func moveToTrash(id: VaultObjectID) async throws {
        try await moveToTrashUseCase.execute(id: id)
    }

    func restore(id: VaultObjectID) async throws {
        try await restoreUseCase.execute(id: id)
    }

    private func validate(_ aggregate: CardAggregate) throws {
        do {
            try validator.validate(aggregate)
        } catch let error as ValidationError {
            throw ApplicationServiceError.validation(error)
        }
    }
}
