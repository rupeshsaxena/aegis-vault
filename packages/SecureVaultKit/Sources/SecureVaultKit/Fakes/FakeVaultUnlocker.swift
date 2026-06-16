import Foundation

public actor FakeVaultUnlocker: VaultUnlocking {
    private var unlockedVaultIDs: Set<VaultID>
    public var shouldUnlock: Bool

    public init(unlockedVaultIDs: Set<VaultID> = [], shouldUnlock: Bool = true) {
        self.unlockedVaultIDs = unlockedVaultIDs
        self.shouldUnlock = shouldUnlock
    }

    public func unlock(_ request: UnlockRequest) async throws -> Bool {
        guard shouldUnlock else {
            return false
        }
        unlockedVaultIDs.insert(request.vaultID)
        return true
    }

    public func lock(vaultID: VaultID) async {
        unlockedVaultIDs.remove(vaultID)
    }

    public func isUnlocked(vaultID: VaultID) async -> Bool {
        unlockedVaultIDs.contains(vaultID)
    }
}
