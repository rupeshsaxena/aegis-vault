import Foundation
import XCTest
@testable import SecureVaultKit

final class SearchIndexTests: XCTestCase {
    func testDefaultPolicyIsMemoryOnlyAndSecureByDefault() {
        let policy = SearchIndexPolicy.default

        XCTAssertEqual(policy.storageMode, .inMemoryOnly)
        XCTAssertTrue(policy.rebuildOnUnlock)
        XCTAssertTrue(policy.clearOnLock)
        XCTAssertFalse(policy.includeDeleted)
    }

    func testSearchReturnsMatchingType() async throws {
        let engine = InMemorySearchEngine()
        let entry = makeEntry(type: .document, title: "Annual Report")
        try await engine.index(entry)

        let results = try await engine.search(query: "document", filter: VaultObjectFilter())

        XCTAssertEqual(results.map(\.objectId), [entry.objectId])
    }

    func testSearchExcludesDeletedByDefault() async throws {
        let engine = InMemorySearchEngine()
        try await engine.index(makeEntry(title: "Visible"))
        try await engine.index(makeEntry(title: "Deleted", isDeleted: true))

        let results = try await engine.search(query: "", filter: VaultObjectFilter())

        XCTAssertEqual(results.map(\.title), ["Visible"])
    }

    func testSearchCanIncludeDeleted() async throws {
        let engine = InMemorySearchEngine()
        let deleted = makeEntry(title: "Deleted", isDeleted: true)
        try await engine.index(deleted)

        let results = try await engine.search(
            query: "",
            filter: VaultObjectFilter(includeDeleted: true)
        )

        XCTAssertEqual(results.map(\.objectId), [deleted.objectId])
    }

    func testSearchCanFilterByType() async throws {
        let engine = InMemorySearchEngine()
        let note = makeEntry(type: .secureNote, title: "Shared Word")
        let card = makeEntry(type: .card, title: "Shared Word")
        try await engine.index(note)
        try await engine.index(card)

        let results = try await engine.search(
            query: "shared",
            filter: VaultObjectFilter(types: [.card])
        )

        XCTAssertEqual(results.map(\.objectId), [card.objectId])
    }

    func testEmptyQueryReturnsAllVisibleEntries() async throws {
        let engine = InMemorySearchEngine()
        try await engine.index(makeEntry(title: "First"))
        try await engine.index(makeEntry(title: "Second"))

        let results = try await engine.search(query: "  ", filter: VaultObjectFilter())

        XCTAssertEqual(results.count, 2)
    }

    func testRebuildReplacesExistingEntries() async throws {
        let engine = InMemorySearchEngine()
        try await engine.index(makeEntry(title: "Stale"))
        let summary = VaultObjectSummary(
            id: VaultObjectID("rebuilt"),
            type: .identity,
            title: "Current",
            tags: ["active"],
            updatedAt: Date(timeIntervalSince1970: 20)
        )

        try await engine.rebuild(from: [summary])

        let entries = await engine.allEntries()
        XCTAssertEqual(entries.map(\.objectId), [summary.id])
        XCTAssertEqual(entries.first?.searchableText, "current active identity")
    }

    func testUpdateObjectUpdatesSearchIndex() async throws {
        let configuration = makeInMemoryConfiguration()
        let engine = DefaultVaultEngine(configuration: configuration)
        _ = try await engine.createVault(config: makeVaultConfig())
        let objectId = try await engine.createObject(
            VaultObjectDraft(
                type: .secureNote,
                metadata: VaultMetadata(title: "Old Search Title"),
                payload: VaultPayload(fields: ["body": .secureText("secret")])
            )
        )

        _ = try await engine.updateObject(
            VaultObjectUpdate(
                objectId: objectId,
                metadata: VaultMetadata(title: "New Search Title", tags: ["updated"])
            )
        )

        let oldResults = try await engine.searchObjects(query: "old")
        let updatedResults = try await engine.searchObjects(query: "updated")
        XCTAssertTrue(oldResults.isEmpty)
        XCTAssertEqual(updatedResults.map(\.id), [objectId])
    }

    func testNoSearchEntriesRemainAfterLock() async throws {
        let configuration = makeInMemoryConfiguration()
        let engine = DefaultVaultEngine(configuration: configuration)
        let vaultId = try await engine.createVault(config: makeVaultConfig())
        _ = try await engine.createObject(
            VaultObjectDraft(
                type: .secureNote,
                metadata: VaultMetadata(title: "Runtime Secret"),
                payload: VaultPayload(fields: ["body": .secureText("secret")])
            )
        )

        await engine.lockVault(id: vaultId)

        let entries = await configuration.searchEngine.allEntries()
        XCTAssertTrue(entries.isEmpty)
    }

    private func makeEntry(
        type: VaultObjectType = .secureNote,
        title: String,
        isDeleted: Bool = false
    ) -> SearchIndexEntry {
        SearchIndexEntry(
            objectId: VaultObjectID(),
            type: type,
            title: title,
            tags: [],
            updatedAt: Date(timeIntervalSince1970: 10),
            isDeleted: isDeleted
        )
    }

    private func makeVaultConfig() -> VaultCreationConfig {
        VaultCreationConfig(
            name: "Search Test",
            deviceID: DeviceID("search-device"),
            unlockMethod: .passphrase
        )
    }
}
