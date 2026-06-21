import SecureVaultKit

enum IdentityEditorState: Equatable {
    case idle
    case editing
    case saving
    case saved(VaultObjectID)
    case failed(String)
}

enum IdentityEditorMode: Equatable, Hashable, Sendable {
    case create(VaultID)
    case edit(VaultObjectID)
}
