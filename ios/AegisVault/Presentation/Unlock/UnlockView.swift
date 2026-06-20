import SecureVaultKit
import SwiftUI

struct UnlockView: View {
    let vaultID: VaultID
    @ObservedObject var viewModel: UnlockViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 48))
                if let errorMessage = viewModel.state.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
                Button {
                    Task { await viewModel.unlock(vaultID: vaultID) }
                } label: {
                    if viewModel.state.isUnlocking {
                        ProgressView()
                    } else {
                        Label("Unlock", systemImage: "faceid")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.state.isUnlocking)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("AegisVault")
        }
    }
}
