internal protocol SearchEngine: Sendable {
    func index(_ entry: SearchIndexEntry) async throws
    func remove(objectId: VaultObjectID) async throws
    func clear() async
    func search(query: String, filter: VaultObjectFilter) async throws -> [SearchIndexEntry]
    func rebuild(from summaries: [VaultObjectSummary]) async throws
    func allEntries() async -> [SearchIndexEntry]
}

extension SearchEngine {
    func index(_ summary: VaultObjectSummary) async throws {
        try await index(SearchIndexEntry(summary: summary))
    }

    func search(query: String) async throws -> [VaultObjectSummary] {
        try await search(query: query, filter: VaultObjectFilter()).map(\.summary)
    }

    func all() async throws -> [VaultObjectSummary] {
        await allEntries().map(\.summary)
    }

    func indexSummary(_ summary: VaultObjectSummary) async throws {
        try await index(summary)
    }

    func listSummaries(
        in vaultId: VaultID,
        matching filter: VaultObjectFilter
    ) async throws -> [VaultObjectSummary] {
        try await search(query: filter.query ?? "", filter: filter)
            .filter { $0.vaultId == vaultId }
            .map(\.summary)
    }

    func indexObject(_ object: VaultObjectRecord) async throws {
        try await index(
            SearchIndexEntry(
                objectId: object.id,
                vaultId: object.vaultId,
                type: object.type,
                title: "",
                tags: [],
                updatedAt: object.updatedAt,
                isDeleted: object.isDeleted,
                version: object.version
            )
        )
    }

    func removeObject(id: VaultObjectID) async throws {
        try await remove(objectId: id)
    }

    func search(
        in vaultId: VaultID,
        matching filter: VaultObjectFilter
    ) async throws -> [VaultObjectID] {
        try await search(query: filter.query ?? "", filter: filter)
            .filter { $0.vaultId == vaultId }
            .map(\.objectId)
    }
}
