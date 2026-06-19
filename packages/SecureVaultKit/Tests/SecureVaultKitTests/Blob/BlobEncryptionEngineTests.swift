import Foundation
import XCTest
@testable import SecureVaultKit

final class BlobEncryptionEngineTests: XCTestCase {
    func testFakeEncryptBlobCreatesOutputFile() async throws {
        let fixture = try makeFixture(contents: Data("stream me".utf8))
        defer { fixture.cleanup() }
        let outputURL = fixture.directory.appendingPathComponent("encrypted.blob")

        _ = try await FakeBlobEncryptionEngine().encryptBlob(
            inputURL: fixture.inputURL,
            outputURL: outputURL,
            using: makeKey()
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
    }

    func testFakeDecryptBlobCreatesReadableFile() async throws {
        let fixture = try makeFixture(contents: Data("readable output".utf8))
        defer { fixture.cleanup() }
        let encryptedURL = fixture.directory.appendingPathComponent("encrypted.blob")
        let decryptedURL = fixture.directory.appendingPathComponent("decrypted.txt")
        let engine = FakeBlobEncryptionEngine()
        let key = makeKey()
        _ = try await engine.encryptBlob(inputURL: fixture.inputURL, outputURL: encryptedURL, using: key)

        let result = try await engine.decryptBlob(
            inputURL: encryptedURL,
            outputURL: decryptedURL,
            using: key
        )

        XCTAssertEqual(result.outputURL, decryptedURL)
        XCTAssertTrue(FileManager.default.isReadableFile(atPath: decryptedURL.path))
    }

    func testEncryptedBlobResultContainsEnvelope() async throws {
        let fixture = try makeFixture(contents: Data([1, 2, 3]))
        defer { fixture.cleanup() }
        let key = makeKey()

        let result = try await FakeBlobEncryptionEngine().encryptBlob(
            inputURL: fixture.inputURL,
            outputURL: fixture.directory.appendingPathComponent("output.blob"),
            using: key
        )

        XCTAssertEqual(result.envelope.version, 1)
        XCTAssertEqual(result.envelope.algorithm, .xChaCha20Poly1305)
        XCTAssertEqual(result.envelope.keyId, key.keyId)
        XCTAssertFalse(result.envelope.nonce.isEmpty)
    }

    func testEncryptedBlobResultContainsSizes() async throws {
        let fixture = try makeFixture(contents: Data(repeating: 7, count: 4_097))
        defer { fixture.cleanup() }

        let result = try await FakeBlobEncryptionEngine(
            policy: BlobEncryptionPolicy(chunkSize: 128)
        ).encryptBlob(
            inputURL: fixture.inputURL,
            outputURL: fixture.directory.appendingPathComponent("output.blob"),
            using: makeKey()
        )

        XCTAssertEqual(result.originalSizeBytes, 4_097)
        XCTAssertEqual(result.encryptedSizeBytes, 4_097)
    }

    func testEncryptedBlobResultContainsChecksum() async throws {
        let fixture = try makeFixture(contents: Data("checksum".utf8))
        defer { fixture.cleanup() }

        let result = try await FakeBlobEncryptionEngine().encryptBlob(
            inputURL: fixture.inputURL,
            outputURL: fixture.directory.appendingPathComponent("output.blob"),
            using: makeKey()
        )

        XCTAssertEqual(result.checksum.count, 64)
        XCTAssertTrue(result.checksum.allSatisfy { $0.isHexDigit })
    }

    func testChecksumChangesWhenInputChanges() async throws {
        let first = try makeFixture(contents: Data("first".utf8))
        let second = try makeFixture(contents: Data("second".utf8))
        defer {
            first.cleanup()
            second.cleanup()
        }
        let engine = FakeBlobEncryptionEngine()

        let firstResult = try await engine.encryptBlob(
            inputURL: first.inputURL,
            outputURL: first.directory.appendingPathComponent("output.blob"),
            using: makeKey()
        )
        let secondResult = try await engine.encryptBlob(
            inputURL: second.inputURL,
            outputURL: second.directory.appendingPathComponent("output.blob"),
            using: makeKey()
        )

        XCTAssertNotEqual(firstResult.checksum, secondResult.checksum)
    }

    func testEncryptRejectsFileLargerThanPolicy() async throws {
        let fixture = try makeFixture(contents: Data(repeating: 1, count: 17))
        defer { fixture.cleanup() }
        let engine = FakeBlobEncryptionEngine(
            policy: BlobEncryptionPolicy(chunkSize: 4, maxFileSizeBytes: 16)
        )

        do {
            _ = try await engine.encryptBlob(
                inputURL: fixture.inputURL,
                outputURL: fixture.directory.appendingPathComponent("output.blob"),
                using: makeKey()
            )
            XCTFail("Expected oversized blob encryption to fail.")
        } catch {
            XCTAssertEqual(error as? BlobEncryptionError, .fileTooLarge(maxFileSizeBytes: 16))
        }
    }

    func testEncryptFailureDoesNotLeavePartialOutput() async throws {
        let fixture = try makeFixture(contents: Data("fail safely".utf8))
        defer { fixture.cleanup() }
        let engine = FakeBlobEncryptionEngine()
        let outputURL = fixture.directory.appendingPathComponent("output.blob")
        await engine.failNextEncryption()

        do {
            _ = try await engine.encryptBlob(
                inputURL: fixture.inputURL,
                outputURL: outputURL,
                using: makeKey()
            )
            XCTFail("Expected injected encryption failure.")
        } catch {
            XCTAssertEqual(error as? BlobEncryptionError, .injectedFailure)
        }

        XCTAssertFalse(FileManager.default.fileExists(atPath: outputURL.path))
        let remainingFiles = try FileManager.default.contentsOfDirectory(atPath: fixture.directory.path)
        XCTAssertFalse(remainingFiles.contains { $0.contains(".partial-") })
    }

    func testDecryptedOutputMatchesOriginalForFakeEngine() async throws {
        let original = Data((0..<20_000).map { UInt8($0 % 251) })
        let fixture = try makeFixture(contents: original)
        defer { fixture.cleanup() }
        let encryptedURL = fixture.directory.appendingPathComponent("encrypted.blob")
        let decryptedURL = fixture.directory.appendingPathComponent("decrypted.bin")
        let engine = FakeBlobEncryptionEngine(policy: BlobEncryptionPolicy(chunkSize: 257))
        let key = makeKey()
        _ = try await engine.encryptBlob(inputURL: fixture.inputURL, outputURL: encryptedURL, using: key)

        _ = try await engine.decryptBlob(inputURL: encryptedURL, outputURL: decryptedURL, using: key)

        XCTAssertEqual(try Data(contentsOf: decryptedURL), original)
    }

    func testImportDocumentUsesBlobEncryptionEngine() async throws {
        let blobEncryptionEngine = FakeBlobEncryptionEngine()
        let configuration = makeInMemoryConfiguration(blobEncryptionEngine: blobEncryptionEngine)
        let engine = DefaultVaultEngine(configuration: configuration)
        let vaultId = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Streaming Test",
                deviceID: DeviceID("streaming-device"),
                unlockMethod: .passphrase
            )
        )
        let fixture = try makeFixture(contents: Data("document".utf8), fileName: "document.pdf")
        defer { fixture.cleanup() }

        _ = try await engine.importDocument(
            DocumentImportInput(fileURL: fixture.inputURL, contentType: "application/pdf"),
            into: vaultId
        )

        let encryptionCount = await blobEncryptionEngine.completedEncryptionCount()
        XCTAssertEqual(encryptionCount, 3)
    }

    func testRealBlobEncryptionEngineThrowsNotImplemented() async throws {
        let fixture = try makeFixture(contents: Data([1]))
        defer { fixture.cleanup() }

        do {
            _ = try await RealBlobEncryptionEngine().encryptBlob(
                inputURL: fixture.inputURL,
                outputURL: fixture.directory.appendingPathComponent("output.blob"),
                using: makeKey()
            )
            XCTFail("Expected real streaming encryption to be unavailable.")
        } catch {
            XCTAssertEqual(error as? CryptoError, .notImplemented)
        }
    }

    private func makeKey() -> SymmetricKeyMaterial {
        SymmetricKeyMaterial(
            keyId: KeyIdentifier("blob-test-key"),
            data: Data("blob-test-key-material".utf8)
        )
    }

    private func makeFixture(
        contents: Data,
        fileName: String = "input.bin"
    ) throws -> FileFixture {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SecureVaultKitBlobEncryption-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let inputURL = directory.appendingPathComponent(fileName)
        try contents.write(to: inputURL)
        return FileFixture(directory: directory, inputURL: inputURL)
    }
}

private struct FileFixture {
    let directory: URL
    let inputURL: URL

    func cleanup() {
        try? FileManager.default.removeItem(at: directory)
    }
}
