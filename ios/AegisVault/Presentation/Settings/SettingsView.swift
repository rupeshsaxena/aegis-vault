import SecureVaultKit
import SwiftUI

struct SettingsView: View {
    let vaultID: VaultID
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Settings")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            viewModel.close(vaultID: vaultID)
                        } label: {
                            Label("Back to Vault", systemImage: "chevron.left")
                        }
                    }
                }
                .task { await viewModel.loadSettings() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView()
        case .loaded(let summary):
            settingsList(summary)
        case .failed(let message):
            ContentUnavailableView {
                Label("Unable to Load Settings", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") {
                    Task { await viewModel.loadSettings() }
                }
            }
        }
    }

    private func settingsList(_ summary: SettingsSummaryViewData) -> some View {
        List {
            Section("Vault") {
                LabeledContent("Status", value: displayName(for: summary.lockState))
            }

            Section("Security") {
                navigationRow("Security Center", systemImage: "lock.shield") {
                    viewModel.showSecurityCenter(vaultID: vaultID)
                }
            }

            Section("Recovery") {
                navigationRow(
                    summary.showsRecoveryWarning ? "Recovery setup incomplete" : "Recovery configured",
                    systemImage: summary.showsRecoveryWarning ? "exclamationmark.triangle" : "checkmark.shield"
                ) {
                    viewModel.showRecovery(vaultID: vaultID)
                }
                .foregroundStyle(summary.showsRecoveryWarning ? .orange : .primary)
            }

            Section("Devices") {
                navigationRow(
                    "Trusted devices: \(summary.trustedDevicesCount)",
                    systemImage: "laptopcomputer.and.iphone"
                ) {
                    viewModel.showDevices(vaultID: vaultID)
                }
            }

            Section("Trash") {
                navigationRow("Manage Trash", systemImage: "trash") {
                    viewModel.showTrash(vaultID: vaultID)
                }
            }

            Section("About") {
                LabeledContent("Application", value: "AegisVault")
                LabeledContent("Privacy", value: "Local-first")
            }
        }
        .listStyle(.insetGrouped)
    }

    private func navigationRow(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .foregroundStyle(.primary)
    }

    private func displayName(for state: VaultSessionState) -> String {
        switch state {
        case .locked: "Locked"
        case .unlocking: "Unlocking"
        case .unlocked: "Unlocked"
        case .locking: "Locking"
        }
    }
}
