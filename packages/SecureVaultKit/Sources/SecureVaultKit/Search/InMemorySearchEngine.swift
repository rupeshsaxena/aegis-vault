internal actor InMemorySearchEngine: SearchEngine {
    private let policy: SearchIndexPolicy
    private var entriesByID: [VaultObjectID: SearchIndexEntry] = [:]

    init(policy: SearchIndexPolicy = .default) {
        self.policy = policy
    }

    func index(_ entry: SearchIndexEntry) async throws {
        entriesByID[entry.objectId] = entry
    }

    func remove(objectId: VaultObjectID) async throws {
        entriesByID[objectId] = nil
    }

    func clear() async {
        entriesByID.removeAll(keepingCapacity: false)
    }

    func search(
        query: String,
        filter: VaultObjectFilter = VaultObjectFilter()
    ) async throws -> [SearchIndexEntry] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let includeDeleted = policy.includeDeleted || filter.includeDeleted

        return entriesByID.values
            .filter { includeDeleted || !$0.isDeleted }
            .filter { filter.types.isEmpty || filter.types.contains($0.type) }
            .filter { entry in
                filter.tags.allSatisfy { entry.tags.contains($0) }
            }
            .filter { normalizedQuery.isEmpty || $0.searchableText.contains(normalizedQuery) }
            .sorted { $0.updatedAt < $1.updatedAt }
    }

    func rebuild(from summaries: [VaultObjectSummary]) async throws {
        guard policy.rebuildOnUnlock else {
            await clear()
            return
        }
        entriesByID = Dictionary(
            uniqueKeysWithValues: summaries
                .map(SearchIndexEntry.init(summary:))
                .filter { policy.includeDeleted || !$0.isDeleted }
                .map { ($0.objectId, $0) }
        )
    }

    func allEntries() async -> [SearchIndexEntry] {
        entriesByID.values.sorted { $0.updatedAt < $1.updatedAt }
    }
}
