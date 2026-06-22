import SecureVaultKit
import SwiftUI

struct SecurityCenterView: View {
    let vaultID: VaultID
    @ObservedObject var viewModel: SecurityCenterViewModel

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Security Center")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            viewModel.close(vaultID: vaultID)
                        } label: {
                            Label("Back to Settings", systemImage: "chevron.left")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Task { await viewModel.lock(vaultID: vaultID) }
                        } label: {
                            Label("Lock", systemImage: "lock")
                        }
                    }
                }
                .task { await viewModel.loadSecurityStatus() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView()
        case .loaded(let status):
            securityList(status)
        case .failed(let message):
            ContentUnavailableView {
                Label("Unable to Load Security", systemImage: "exclamationmark.shield")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") {
                    Task { await viewModel.loadSecurityStatus() }
                }
            }
        }
    }

    private func securityList(_ status: SecurityStatusViewData) -> some View {
        List {
            Section("Vault") {
                LabeledContent("Lock state", value: status.lockState.rawValue.capitalized)
                Picker("Auto-lock", selection: autoLockBinding(status.autoLockPolicy)) {
                    ForEach(AutoLockPolicy.allCases, id: \.self) { policy in
                        Text(displayName(for: policy)).tag(policy)
                    }
                }
            }

            Section("Authentication") {
                LabeledContent("Biometric", value: displayName(for: status.biometricStatus))
                LabeledContent("Passkey", value: displayName(for: status.passkeyStatus))
                Text("Authentication setup is not available in this version.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Recovery") {
                LabeledContent(
                    "Recovery package",
                    value: status.showsRecoveryWarning ? "Incomplete" : "Configured"
                )
                if status.showsRecoveryWarning {
                    Label(
                        "Complete recovery setup to protect against device loss.",
                        systemImage: "exclamationmark.triangle"
                    )
                    .foregroundStyle(.orange)
                }
            }

            Section("Trusted Devices") {
                if status.trustedDevices.isEmpty {
                    Text("No trusted devices")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(status.trustedDevices) { device in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(device.name)
                            Text(device.isCurrentDevice ? "Current device" : device.platform)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Text("Device management is read-only for now.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
    }

    private func autoLockBinding(_ currentPolicy: AutoLockPolicy) -> Binding<AutoLockPolicy> {
        Binding(
            get: { currentPolicy },
            set: { policy in Task { await viewModel.updateAutoLockPolicy(policy) } }
        )
    }

    private func displayName(for policy: AutoLockPolicy) -> String {
        switch policy {
        case .immediately: "Immediately"
        case .oneMinute: "1 minute"
        case .fiveMinutes: "5 minutes"
        case .fifteenMinutes: "15 minutes"
        case .never: "Never"
        }
    }

    private func displayName(for status: SecuritySetupStatus) -> String {
        switch status {
        case .notConfigured: "Not configured"
        case .configured: "Configured"
        case .unavailable: "Unavailable"
        }
    }
}
