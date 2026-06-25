import SecureVaultKit
import SwiftUI

struct UnlockView: View {
    let vaultID: VaultID
    @ObservedObject var viewModel: UnlockViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 64)).foregroundStyle(.tint)
            Text("Unlock AegisVault")
                .font(.title.bold())
                .accessibilityIdentifier("unlockTitle")
            Text("Vault: \(vaultID.description)")
                .font(.caption).foregroundStyle(.secondary)
            if let error = viewModel.state.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
            }
            Spacer()
            Button {
                Task { await viewModel.unlock(vaultID: vaultID, method: .passphrase) }
            } label: {
                if viewModel.state.isUnlocking {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Text("Unlock").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.state.isUnlocking)
            .padding(.horizontal, 32).padding(.bottom, 40)
            .accessibilityIdentifier("unlockButton")
        }
    }
}
