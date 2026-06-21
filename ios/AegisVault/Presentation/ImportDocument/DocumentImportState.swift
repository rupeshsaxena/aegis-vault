import SecureVaultKit

enum DocumentImportState: Equatable {
    case idle
    case selected(DocumentImportFileInfo)
    case importing(DocumentImportFileInfo, progress: Double)
    case imported(VaultObjectID)
    case failed(String)
}
