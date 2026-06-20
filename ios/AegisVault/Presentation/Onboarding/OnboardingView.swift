import SwiftUI

struct OnboardingView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        NavigationStack {
            Form {
                TextField(
                    "Vault name",
                    text: Binding(
                        get: { viewModel.state.vaultName },
                        set: viewModel.setVaultName
                    )
                )
                if let errorMessage = viewModel.state.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
                Button {
                    Task { await viewModel.createVault() }
                } label: {
                    if viewModel.state.phase == .creating {
                        ProgressView()
                    } else {
                        Label("Create Vault", systemImage: "lock.shield")
                    }
                }
                .disabled(!viewModel.state.canCreateVault)
            }
            .navigationTitle("AegisVault")
        }
    }
}
