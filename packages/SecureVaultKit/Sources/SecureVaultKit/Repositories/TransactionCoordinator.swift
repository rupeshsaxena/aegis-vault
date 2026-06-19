internal enum VaultObjectMutation: Sendable {
    case insert(VaultObjectRecord)
    case update(previous: VaultObjectRecord, updated: VaultObjectRecord)
    case delete(VaultObjectRecord)
}

internal protocol TransactionCoordinator: Sendable {
    func execute(_ mutation: VaultObjectMutation, appending event: VaultEvent) async throws
}

internal struct InMemoryTransactionCoordinator: TransactionCoordinator {
    private let objectRepository: any VaultObjectRepository
    private let eventRepository: any VaultEventRepository

    init(
        objectRepository: any VaultObjectRepository,
        eventRepository: any VaultEventRepository
    ) {
        self.objectRepository = objectRepository
        self.eventRepository = eventRepository
    }

    func execute(_ mutation: VaultObjectMutation, appending event: VaultEvent) async throws {
        try await apply(mutation)
        do {
            try await eventRepository.append(event)
        } catch {
            await rollback(mutation)
            throw error
        }
    }

    private func apply(_ mutation: VaultObjectMutation) async throws {
        switch mutation {
        case .insert(let record):
            try await objectRepository.insert(record)
        case .update(_, let updated):
            try await objectRepository.update(updated)
        case .delete(let record):
            try await objectRepository.remove(id: record.id)
        }
    }

    private func rollback(_ mutation: VaultObjectMutation) async {
        switch mutation {
        case .insert(let record):
            try? await objectRepository.remove(id: record.id)
        case .update(let previous, _):
            try? await objectRepository.update(previous)
        case .delete(let record):
            try? await objectRepository.insert(record)
        }
    }
}

internal struct SQLiteTransactionCoordinator: TransactionCoordinator {
    private let storageEngine: SQLiteStorageEngine

    init(storageEngine: SQLiteStorageEngine) {
        self.storageEngine = storageEngine
    }

    func execute(_ mutation: VaultObjectMutation, appending event: VaultEvent) async throws {
        try await storageEngine.executeObjectMutation(mutation, appending: event)
    }
}
