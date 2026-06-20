import SecureVaultKit

struct VaultHomeState: Equatable {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case failed
    }

    var phase: Phase = .idle
    var objects: [VaultObjectSummary] = []
    var searchQuery = ""
    var errorMessage: String?
    var lockedVaultID: VaultID?
}
