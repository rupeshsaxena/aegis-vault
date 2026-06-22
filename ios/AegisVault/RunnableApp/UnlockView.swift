import SecureVaultKit
import SwiftUI

struct UnlockView: View {
    let vaultID: VaultID

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            Text("Unlock AegisVault")
                .font(.title.bold())
                .accessibilityIdentifier("unlockTitle")

            Text("Vault: \(vaultID.description)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
