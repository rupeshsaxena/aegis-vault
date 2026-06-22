import Foundation

public struct RecoveryStatus: Equatable, Codable, Sendable {
    public let isConfigured: Bool
    public let lastExportedAt: Date?

    public init(isConfigured: Bool, lastExportedAt: Date? = nil) {
        self.isConfigured = isConfigured
        self.lastExportedAt = lastExportedAt
    }
}

public struct RecoveryPackageExport: Equatable, Sendable {
    public let fileName: String
    public let exportedAt: Date
    public let formatVersion: Int
    public let temporaryFileURL: URL?

    public init(
        fileName: String,
        exportedAt: Date,
        formatVersion: Int,
        temporaryFileURL: URL?
    ) {
        self.fileName = fileName
        self.exportedAt = exportedAt
        self.formatVersion = formatVersion
        self.temporaryFileURL = temporaryFileURL
    }
}
