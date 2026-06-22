import Foundation
import SecureVaultKit

enum RecoverySettingsState: Equatable {
    case idle
    case loading
    case loaded(RecoveryStatusViewData)
    case exporting
    case exported(RecoveryExportViewData)
    case failed(String)
}

struct RecoveryStatusViewData: Equatable {
    static let warningMessage = """
    Anyone with your recovery package and recovery secret may be able to recover your vault.

    If you lose both recovery material and all trusted devices, your vault may be unrecoverable.
    """

    let isRecoveryConfigured: Bool
    let lastExportedAt: Date?
    let warningMessage: String

    init(status: RecoveryStatus) {
        isRecoveryConfigured = status.isConfigured
        lastExportedAt = status.lastExportedAt
        warningMessage = Self.warningMessage
    }
}

struct RecoveryExportViewData: Equatable {
    let fileName: String
    let exportedAt: Date
    let temporaryExportURL: URL?

    init(export: RecoveryPackageExport) {
        fileName = export.fileName
        exportedAt = export.exportedAt
        temporaryExportURL = export.temporaryFileURL
    }
}
