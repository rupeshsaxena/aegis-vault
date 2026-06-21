import Foundation

internal actor FakeBlobEncryptionEngine: BlobEncryptionEngine {
    private let policy: BlobEncryptionPolicy
    private var shouldFailNextEncryption = false
    private var shouldFailNextDecryption = false
    private var encryptionCount = 0

    init(policy: BlobEncryptionPolicy = .default) {
        self.policy = policy
    }

    func encryptBlob(
        inputURL: URL,
        outputURL: URL,
        using key: SymmetricKeyMaterial
    ) async throws -> EncryptedBlobResult {
        try validatePolicy()
        if shouldFailNextEncryption {
            shouldFailNextEncryption = false
            throw BlobEncryptionError.injectedFailure
        }

        let plaintext = try FileChecksum.sha256(of: inputURL, chunkSize: policy.chunkSize)
        guard plaintext.sizeBytes <= policy.maxFileSizeBytes else {
            throw BlobEncryptionError.fileTooLarge(maxFileSizeBytes: policy.maxFileSizeBytes)
        }

        let encryptedSize = try FakeBlobTransform.copy(
            from: inputURL,
            to: outputURL,
            chunkSize: policy.chunkSize
        )
        encryptionCount += 1
        let blobId = BlobID()
        let envelope = EncryptedEnvelope(
            version: 1,
            algorithm: policy.algorithm,
            keyId: key.keyId,
            nonce: Data("fake-blob-nonce-\(encryptionCount)".utf8),
            ciphertext: Data("fake-streamed-blob:\(blobId.rawValue)".utf8)
        )
        return EncryptedBlobResult(
            blobId: blobId,
            envelope: envelope,
            originalSizeBytes: plaintext.sizeBytes,
            encryptedSizeBytes: encryptedSize,
            checksum: plaintext.checksum
        )
    }

    func decryptBlob(
        inputURL: URL,
        outputURL: URL,
        using key: SymmetricKeyMaterial
    ) async throws -> DecryptedBlobResult {
        try validatePolicy()
        if shouldFailNextDecryption {
            shouldFailNextDecryption = false
            throw BlobEncryptionError.injectedFailure
        }

        let sizeBytes = try FakeBlobTransform.copy(
            from: inputURL,
            to: outputURL,
            chunkSize: policy.chunkSize
        )
        let plaintext = try FileChecksum.sha256(of: outputURL, chunkSize: policy.chunkSize)
        return DecryptedBlobResult(
            outputURL: outputURL,
            sizeBytes: sizeBytes,
            checksum: plaintext.checksum
        )
    }

    func failNextEncryption() {
        shouldFailNextEncryption = true
    }

    func failNextDecryption() {
        shouldFailNextDecryption = true
    }

    func completedEncryptionCount() -> Int {
        encryptionCount
    }

    private func validatePolicy() throws {
        guard policy.chunkSize > 0, policy.maxFileSizeBytes >= 0 else {
            throw BlobEncryptionError.invalidPolicy
        }
    }
}

private enum FakeBlobTransform {
    // Reversible test transform only. It deliberately provides no security claim.
    static func copy(from sourceURL: URL, to destinationURL: URL, chunkSize: Int) throws -> Int64 {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: destinationURL)
        guard fileManager.createFile(atPath: destinationURL.path, contents: nil) else {
            throw BlobEncryptionError.injectedFailure
        }

        let source = try FileHandle(forReadingFrom: sourceURL)
        let destination = try FileHandle(forWritingTo: destinationURL)
        var succeeded = false
        defer {
            try? source.close()
            try? destination.close()
            if !succeeded {
                try? fileManager.removeItem(at: destinationURL)
            }
        }

        var total: Int64 = 0
        while let data = try source.read(upToCount: chunkSize), !data.isEmpty {
            try Task.checkCancellation()
            let transformed = Data(data.map { $0 ^ 0xA5 })
            try destination.write(contentsOf: transformed)
            total += Int64(transformed.count)
        }
        succeeded = true
        return total
    }
}
