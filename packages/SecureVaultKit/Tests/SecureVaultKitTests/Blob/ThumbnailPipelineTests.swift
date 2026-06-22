import Foundation
import XCTest
@testable import SecureVaultKit

final class ThumbnailPipelineTests: XCTestCase {
    func testLoadThumbnailFailsWhenLocked() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())

        await XCTAssertThrowsVaultError(.locked) {
            _ = try await engine.loadThumbnail(for: VaultObjectID("document"))
        }
    }

    func testLoadThumbnailReturnsThumbnailForImportedDocument() async throws {
        let fixture = try await makeImportedDocument()
        defer { try? FileManager.default.removeItem(at: fixture.sourceDirectory) }

        let thumbnail = try await fixture.engine.loadThumbnail(for: fixture.objectId)

        XCTAssertEqual(thumbnail.objectId, fixture.objectId)
        XCTAssertEqual(thumbnail.contentType, "image/png")
        XCTAssertTrue(thumbnail.data.contains(Data("pdf-thumbnail".utf8)))
        XCTAssertNotNil(thumbnail.createdAt)
    }

    func testLoadThumbnailReturnsNotFoundWithoutAttachment() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        _ = try await engine.createVault(config: vaultConfig())
        let objectId = try await engine.createObject(
            VaultObjectDraft(
                type: .document,
                metadata: VaultMetadata(title: "Placeholder"),
                payload: VaultPayload()
            )
        )

        await XCTAssertThrowsVaultError(.thumbnailNotFound(objectId)) {
            _ = try await engine.loadThumbnail(for: objectId)
        }
    }

    func testLockVaultClearsThumbnailCache() async throws {
        let cache = InMemoryThumbnailCache()
        let engine = DefaultVaultEngine(
            configuration: makeInMemoryConfiguration(),
            thumbnailCache: cache
        )
        let source = try makePDF()
        defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }
        let vaultId = try await engine.createVault(config: vaultConfig())
        let result = try await engine.importDocument(
            DocumentImportInput(fileURL: source, contentType: "application/pdf"),
            into: vaultId
        )
        _ = try await engine.loadThumbnail(for: result.objectId)
        let populatedCount = await cache.count()
        XCTAssertEqual(populatedCount, 1)

        await engine.lockVault(id: vaultId)

        let clearedCount = await cache.count()
        XCTAssertEqual(clearedCount, 0)
        await XCTAssertThrowsVaultError(.locked) {
            _ = try await engine.loadThumbnail(for: result.objectId)
        }
    }

    func testThumbnailCacheIsInMemoryOnly() async {
        let cache = InMemoryThumbnailCache()
        let thumbnail = VaultThumbnail(
            objectId: VaultObjectID("object"),
            data: Data("display-data".utf8),
            contentType: "image/png"
        )

        await cache.insert(thumbnail)

        let cached = await cache.value(for: thumbnail.objectId)
        let populatedCount = await cache.count()
        XCTAssertEqual(cached, thumbnail)
        XCTAssertEqual(populatedCount, 1)
        await cache.clear()
        let clearedCount = await cache.count()
        XCTAssertEqual(clearedCount, 0)
    }

    func testThumbnailPublicAPIDoesNotExposeBlobStore() throws {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let publicFiles = [
            packageRoot.appendingPathComponent("Sources/SecureVaultKit/Public/VaultEngine.swift"),
            packageRoot.appendingPathComponent("Sources/SecureVaultKit/Public/VaultThumbnail.swift")
        ]

        for fileURL in publicFiles {
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            XCTAssertFalse(source.contains("BlobStore"))
            XCTAssertFalse(source.contains("CryptoEngine"))
            XCTAssertFalse(source.contains("StorageEngine"))
        }
    }

    private func makeImportedDocument() async throws -> (
        engine: DefaultVaultEngine,
        objectId: VaultObjectID,
        sourceDirectory: URL
    ) {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        let vaultId = try await engine.createVault(config: vaultConfig())
        let source = try makePDF()
        let result = try await engine.importDocument(
            DocumentImportInput(fileURL: source, contentType: "application/pdf"),
            into: vaultId
        )
        return (engine, result.objectId, source.deletingLastPathComponent())
    }

    private func makePDF() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ThumbnailPipelineTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("document.pdf")
        try Data("%PDF thumbnail source".utf8).write(to: fileURL)
        return fileURL
    }

    private func vaultConfig() -> VaultCreationConfig {
        VaultCreationConfig(
            name: "Thumbnail Test",
            deviceID: DeviceID("device"),
            unlockMethod: .passphrase
        )
    }
}
