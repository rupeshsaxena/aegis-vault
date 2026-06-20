public enum VaultRuntimeStatus: Equatable, Sendable {
    case missing
    case locked(VaultID)
    case unlocked(VaultID)
}
