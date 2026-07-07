import SecureVaultKit

protocol SecureNoteApplicationServicing: Sendable {
    func createNote(_ data: SecureNoteEditorViewData) async throws -> VaultObjectID
    func updateNote(existing: VaultObjectDetail, data: SecureNoteEditorViewData) async throws -> VaultObjectID
    func loadNote(id: VaultObjectID) async throws -> VaultObjectDetail
    func moveToTrash(id: VaultObjectID) async throws
    func restore(id: VaultObjectID) async throws
}

struct SecureNoteApplicationService: SecureNoteApplicationServicing {
    private let createUseCase: any CreateSecureNoteUsing
    private let updateUseCase: any UpdateSecureNoteUsing
    private let detailUseCase: any GetObjectDetailUsing
    private let moveToTrashUseCase: any MoveObjectToTrashUsing
    private let restoreUseCase: any RestoreFromTrashUsing
    private let validator: SecureNoteValidator

    init(
        createUseCase: any CreateSecureNoteUsing,
        updateUseCase: any UpdateSecureNoteUsing,
        detailUseCase: any GetObjectDetailUsing,
        moveToTrashUseCase: any MoveObjectToTrashUsing,
        restoreUseCase: any RestoreFromTrashUsing,
        validator: SecureNoteValidator = SecureNoteValidator()
    ) {
        self.createUseCase = createUseCase
        self.updateUseCase = updateUseCase
        self.detailUseCase = detailUseCase
        self.moveToTrashUseCase = moveToTrashUseCase
        self.restoreUseCase = restoreUseCase
        self.validator = validator
    }

    func createNote(_ data: SecureNoteEditorViewData) async throws -> VaultObjectID {
        try validate(SecureNoteAggregate(data: data))
        return try await createUseCase.execute(data: data)
    }

    func updateNote(existing: VaultObjectDetail, data: SecureNoteEditorViewData) async throws -> VaultObjectID {
        try validate(SecureNoteAggregate(data: data))
        return try await updateUseCase.execute(existing: existing, data: data)
    }

    func loadNote(id: VaultObjectID) async throws -> VaultObjectDetail {
        try await detailUseCase.execute(id: id)
    }

    func moveToTrash(id: VaultObjectID) async throws {
        try await moveToTrashUseCase.execute(id: id)
    }

    func restore(id: VaultObjectID) async throws {
        try await restoreUseCase.execute(id: id)
    }

    private func validate(_ aggregate: SecureNoteAggregate) throws {
        do {
            try validator.validate(aggregate)
        } catch let error as ValidationError {
            throw ApplicationServiceError.validation(error)
        }
    }
}
