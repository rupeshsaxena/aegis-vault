import Foundation
import XCTest
@testable import SecureVaultKit

final class FakeImplementationTests: XCTestCase {
    func testInMemoryRepositoryStoresListsTrashesRestoresAndPurgesItems() async throws {
        let vaultID = VaultID("vault-1")
        let itemID = VaultItemID("item-1")
        let repository = InMemoryVaultRepository()
        let vault = Vault(id: vaultID, name: "Primary")
        let item = VaultItem(
            id: itemID,
            vaultID: vaultID,
            title: "Passport",
            kind: .secureNote,
            payload: .secureNote(SecureNote(body: "Document location"))
        )

        try await repository.createVault(vault)
        try await repository.upsertItem(item)

        let visibleItems = try await repository.listItems(in: vaultID, includeDeleted: false)
        XCTAssertEqual(visibleItems.map(\.id), [itemID])

        let deletedAt = Date(timeIntervalSince1970: 100)
        try await repository.moveItemToTrash(id: itemID, at: deletedAt)

        let afterTrash = try await repository.listItems(in: vaultID, includeDeleted: false)
        XCTAssertTrue(afterTrash.isEmpty)
        let trashedItem = try await repository.fetchItem(id: itemID)
        XCTAssertTrue(trashedItem.isDeleted)

        try await repository.restoreItem(id: itemID)
        let restoredItem = try await repository.fetchItem(id: itemID)
        XCTAssertFalse(restoredItem.isDeleted)

        try await repository.moveItemToTrash(id: itemID, at: deletedAt)
        let purged = try await repository.purgeDeletedItems(olderThan: Date(timeIntervalSince1970: 101))
        XCTAssertEqual(purged, [itemID])

        await XCTAssertThrowsSecureVaultError(.itemNotFound(itemID)) {
            _ = try await repository.fetchItem(id: itemID)
        }
    }

    func testRepositoryRejectsItemsForMissingVaults() async {
        let repository = InMemoryVaultRepository()
        let missingVaultID = VaultID("missing")
        let item = VaultItem(
            vaultID: missingVaultID,
            title: "Orphaned",
            kind: .secureNote,
            payload: .secureNote(SecureNote(body: "No parent vault"))
        )

        await XCTAssertThrowsSecureVaultError(.vaultNotFound(missingVaultID)) {
            try await repository.upsertItem(item)
        }
    }

    func testFakeCryptoProviderIsExplicitlyNoop() async throws {
        let crypto = FakeCryptoProvider()
        let plaintext = Data("not encrypted yet".utf8)

        let encrypted = try await crypto.encrypt(plaintext, context: "unit-test")
        let decrypted = try await crypto.decrypt(encrypted, context: "unit-test")

        XCTAssertEqual(encrypted.algorithm, FakeCryptoProvider.algorithm)
        XCTAssertEqual(encrypted.ciphertext, plaintext)
        XCTAssertEqual(encrypted.nonce, Data("unit-test".utf8))
        XCTAssertEqual(decrypted, plaintext)
    }

    func testFakeUnlockerTracksLockState() async throws {
        let vaultID = VaultID("vault-1")
        let unlocker = FakeVaultUnlocker()

        let initiallyUnlocked = await unlocker.isUnlocked(vaultID: vaultID)
        XCTAssertFalse(initiallyUnlocked)

        let didUnlock = try await unlocker.unlock(
            UnlockRequest(vaultID: vaultID, method: .biometric, reason: "Open vault")
        )

        XCTAssertTrue(didUnlock)
        let unlockedAfterRequest = await unlocker.isUnlocked(vaultID: vaultID)
        XCTAssertTrue(unlockedAfterRequest)

        await unlocker.lock(vaultID: vaultID)
        let unlockedAfterLock = await unlocker.isUnlocked(vaultID: vaultID)
        XCTAssertFalse(unlockedAfterLock)
    }

    func testInMemoryBlobStoreRoundTripsData() async throws {
        let store = InMemoryBlobStore()
        let blobID = BlobID("blob-1")
        let data = Data([1, 2, 3])

        try await store.putBlob(id: blobID, data: data)
        let storedData = try await store.getBlob(id: blobID)
        XCTAssertEqual(storedData, data)

        try await store.deleteBlob(id: blobID)
        await XCTAssertThrowsSecureVaultError(.blobNotFound(blobID)) {
            _ = try await store.getBlob(id: blobID)
        }
    }

    func testEventLogFiltersAndOrdersEvents() async throws {
        let vaultID = VaultID("vault-1")
        let otherVaultID = VaultID("vault-2")
        let log = InMemoryVaultEventLog()

        try await log.append(VaultEvent(vaultID: vaultID, kind: .itemUpdated, occurredAt: Date(timeIntervalSince1970: 2)))
        try await log.append(VaultEvent(vaultID: otherVaultID, kind: .vaultCreated, occurredAt: Date(timeIntervalSince1970: 1)))
        try await log.append(VaultEvent(vaultID: vaultID, kind: .vaultCreated, occurredAt: Date(timeIntervalSince1970: 1)))

        let events = try await log.listEvents(for: vaultID)

        XCTAssertEqual(events.map(\.kind), [.vaultCreated, .itemUpdated])
    }
}

private func XCTAssertThrowsSecureVaultError(
    _ expectedError: SecureVaultError,
    file: StaticString = #filePath,
    line: UInt = #line,
    operation: () async throws -> Void
) async {
    do {
        try await operation()
        XCTFail("Expected \(expectedError) to be thrown.", file: file, line: line)
    } catch let error as SecureVaultError {
        XCTAssertEqual(error, expectedError, file: file, line: line)
    } catch {
        XCTFail("Expected \(expectedError), got \(error).", file: file, line: line)
    }
}
