import Foundation

actor RecoveryPackageStager {
    func stagePackage(from sourceURL: URL) async throws -> URL {
        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("RecoveryImport-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let destinationURL = tempDir.appendingPathComponent(sourceURL.lastPathComponent)

        do {
            try await copyFile(from: sourceURL, to: destinationURL)
            return destinationURL
        } catch {
            try? FileManager.default.removeItem(at: destinationURL)
            try? FileManager.default.removeItem(at: tempDir)
            throw error
        }
    }

    private func copyFile(from sourceURL: URL, to destinationURL: URL) async throws {
        let input = try FileHandle(forReadingFrom: sourceURL)
        defer { try? input.close() }

        FileManager.default.createFile(atPath: destinationURL.path, contents: nil)
        let output = try FileHandle(forWritingTo: destinationURL)
        defer { try? output.close() }

        while true {
            try Task.checkCancellation()
            let chunk = try input.read(upToCount: 1_048_576) ?? Data()
            guard !chunk.isEmpty else { break }
            try output.write(contentsOf: chunk)
        }
    }
}
