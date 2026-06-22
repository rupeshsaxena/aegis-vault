import SecureVaultKit

struct AppContainer {
    let secureVaultKitType: VaultID.Type

    init() {
        secureVaultKitType = VaultID.self
    }
}

