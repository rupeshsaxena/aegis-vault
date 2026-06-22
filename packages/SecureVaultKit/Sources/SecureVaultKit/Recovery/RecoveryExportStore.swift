import Foundation

internal actor RecoveryExportStore {
    static let formatVersion = 1
    static let fileName = "AegisVault-Recovery-Package.json"

    private let fileManager: FileManager
    private var activeExportURL: URL?
    private var lastExportedAt: Date?

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func status() -> RecoveryStatus {
        RecoveryStatus(isConfigured: false, lastExportedAt: lastExportedAt)
    }

    func createExport(vaultId: VaultID, deviceId: DeviceID) throws -> RecoveryPackageExport {
        try clearTemporaryExport()
        let exportedAt = Date()
        let payload = RecoveryExportPayload(
            packageVersion: Self.formatVersion,
            packageId: UUID().uuidString,
            vaultId: vaultId,
            deviceId: deviceId,
            createdAt: exportedAt,
            recoverySetupState: .incomplete
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)
        let directoryURL = fileManager.temporaryDirectory
            .appendingPathComponent("SecureVaultKit-Recovery-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let fileURL = directoryURL.appendingPathComponent(Self.fileName)
        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            try? fileManager.removeItem(at: directoryURL)
            throw error
        }
        activeExportURL = fileURL
        lastExportedAt = exportedAt
        return RecoveryPackageExport(
            fileName: Self.fileName,
            exportedAt: exportedAt,
            formatVersion: Self.formatVersion,
            temporaryFileURL: fileURL
        )
    }

    func clearTemporaryExport() throws {
        guard let activeExportURL else { return }
        try? fileManager.removeItem(at: activeExportURL.deletingLastPathComponent())
        self.activeExportURL = nil
    }

    func discardFailedExport() throws {
        try clearTemporaryExport()
        lastExportedAt = nil
    }
}

private struct RecoveryExportPayload: Codable {
    let packageVersion: Int
    let packageId: String
    let vaultId: VaultID
    let deviceId: DeviceID
    let createdAt: Date
    let recoverySetupState: RecoverySetupStatus
}
