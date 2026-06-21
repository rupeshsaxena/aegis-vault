import SecureVaultKit

enum CardEditorState: Equatable {
    case idle
    case editing
    case saving
    case saved(VaultObjectID)
    case failed(String)
}

enum CardEditorMode: Equatable, Hashable, Sendable {
    case create(VaultID)
    case edit(VaultObjectID)
}
