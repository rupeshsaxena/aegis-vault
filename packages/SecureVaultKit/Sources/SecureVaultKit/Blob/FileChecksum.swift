import CryptoKit
import Foundation

internal enum FileChecksum {
    static func sha256(
        of fileURL: URL,
        chunkSize: Int
    ) throws -> (checksum: String, sizeBytes: Int64) {
        guard chunkSize > 0 else {
            throw BlobEncryptionError.invalidPolicy
        }

        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }
        var hasher = SHA256()
        var sizeBytes: Int64 = 0

        while true {
            try Task.checkCancellation()
            guard let chunk = try handle.read(upToCount: chunkSize), !chunk.isEmpty else {
                break
            }
            hasher.update(data: chunk)
            sizeBytes += Int64(chunk.count)
        }

        let checksum = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        return (checksum, sizeBytes)
    }
}

internal enum StreamingFileCopy {
    static func copy(
        from inputURL: URL,
        to outputURL: URL,
        chunkSize: Int,
        fileManager: FileManager = .default
    ) throws -> Int64 {
        guard chunkSize > 0 else {
            throw BlobEncryptionError.invalidPolicy
        }

        try fileManager.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let partialURL = outputURL.deletingLastPathComponent()
            .appendingPathComponent(".\(outputURL.lastPathComponent).partial-\(UUID().uuidString)")
        guard fileManager.createFile(atPath: partialURL.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }

        var completed = false
        defer {
            if !completed {
                try? fileManager.removeItem(at: partialURL)
            }
        }

        let input = try FileHandle(forReadingFrom: inputURL)
        let output = try FileHandle(forWritingTo: partialURL)
        defer {
            try? input.close()
            try? output.close()
        }
        var sizeBytes: Int64 = 0

        while true {
            try Task.checkCancellation()
            guard let chunk = try input.read(upToCount: chunkSize), !chunk.isEmpty else {
                break
            }
            try output.write(contentsOf: chunk)
            sizeBytes += Int64(chunk.count)
        }
        try output.synchronize()

        if fileManager.fileExists(atPath: outputURL.path) {
            try fileManager.removeItem(at: outputURL)
        }
        try fileManager.moveItem(at: partialURL, to: outputURL)
        completed = true
        return sizeBytes
    }
}
