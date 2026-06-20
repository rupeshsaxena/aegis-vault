import SecureVaultKit
import SwiftUI

struct UnlockView: View {
    let vaultID: VaultID
    @ObservedObject var viewModel: UnlockViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                Text("Unlock AegisVault")
                    .font(.title.bold())

                if let errorMessage = viewModel.state.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.circle")
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    unlockButton(
                        title: "Unlock with Biometrics",
                        icon: "faceid",
                        method: .biometric,
                        prominent: true
                    )
                    unlockButton(
                        title: "Unlock with Passkey",
                        icon: "person.badge.key",
                        method: .passkey,
                        prominent: false
                    )
                    Button("Use Recovery", systemImage: "key.viewfinder") {
                        viewModel.showRecoveryPlaceholder()
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.state.isUnlocking)
                }
                .frame(maxWidth: 360)
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("AegisVault")
            .overlay {
                if viewModel.state.isUnlocking {
                    ProgressView("Unlocking")
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .alert(
                "Recovery Unlock",
                isPresented: Binding(
                    get: { viewModel.isRecoveryPlaceholderPresented },
                    set: { if !$0 { viewModel.dismissRecoveryPlaceholder() } }
                )
            ) {
                Button("OK") { viewModel.dismissRecoveryPlaceholder() }
            } message: {
                Text("Recovery package import and recovery secret entry will be added in a later milestone.")
            }
        }
    }

    @ViewBuilder
    private func unlockButton(
        title: String,
        icon: String,
        method: UnlockMethod,
        prominent: Bool
    ) -> some View {
        let button = Button(title, systemImage: icon) {
            Task { await viewModel.unlock(vaultID: vaultID, method: method) }
        }
        if prominent {
            button
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.state.isUnlocking)
        } else {
            button
                .buttonStyle(.bordered)
                .disabled(viewModel.state.isUnlocking)
        }
    }
}
