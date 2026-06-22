import SecureVaultKit

enum SecureNoteEditorState: Equatable {
    case idle
    case editing
    case saving
    case saved(VaultObjectID)
    case failed(String)
}

enum SecureNoteEditorMode: Equatable, Hashable, Sendable {
    case create(VaultID)
    case edit(VaultObjectID)
}
