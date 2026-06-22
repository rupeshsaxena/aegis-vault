import SecureVaultKit
import SwiftUI

struct RecoverySettingsView: View {
    let vaultID: VaultID
    @ObservedObject var viewModel: RecoverySettingsViewModel

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Recovery")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            viewModel.close(vaultID: vaultID)
                        } label: {
                            Label("Back to Settings", systemImage: "chevron.left")
                        }
                    }
                }
                .task { await viewModel.loadStatus() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView()
        case .loaded(let status):
            recoveryForm(status)
        case .exporting:
            VStack(spacing: 12) {
                ProgressView()
                Text("Preparing recovery package")
                    .foregroundStyle(.secondary)
            }
        case .exported(let export):
            exportedContent(export)
        case .failed(let message):
            ContentUnavailableView {
                Label("Recovery Action Failed", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") {
                    Task { await viewModel.loadStatus() }
                }
            }
        }
    }

    private func recoveryForm(_ status: RecoveryStatusViewData) -> some View {
        Form {
            Section("Status") {
                LabeledContent(
                    "Recovery setup",
                    value: status.isRecoveryConfigured ? "Configured" : "Incomplete"
                )
                if let lastExportedAt = status.lastExportedAt {
                    LabeledContent(
                        "Last exported",
                        value: lastExportedAt.formatted(date: .abbreviated, time: .shortened)
                    )
                }
            }

            Section("Important") {
                Label(status.warningMessage, systemImage: "exclamationmark.shield")
                    .foregroundStyle(.orange)
            }

            Section {
                Toggle(
                    "I understand my responsibility to protect both recovery materials.",
                    isOn: acknowledgmentBinding
                )
                Button {
                    Task { await viewModel.exportPackage() }
                } label: {
                    Label("Export Recovery Package", systemImage: "square.and.arrow.up")
                }
                .disabled(!viewModel.hasAcknowledgedRisk)
            }
        }
    }

    private func exportedContent(_ export: RecoveryExportViewData) -> some View {
        ContentUnavailableView {
            Label("Recovery Package Ready", systemImage: "checkmark.shield")
        } description: {
            Text("\(export.fileName) was prepared at \(export.exportedAt.formatted(date: .abbreviated, time: .shortened)).")
        } actions: {
            if let url = export.temporaryExportURL {
                ShareLink(item: url) {
                    Label("Share Recovery Package", systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    private var acknowledgmentBinding: Binding<Bool> {
        Binding(
            get: { viewModel.hasAcknowledgedRisk },
            set: viewModel.setAcknowledgedRisk
        )
    }
}
