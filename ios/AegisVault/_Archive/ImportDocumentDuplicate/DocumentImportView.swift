import SecureVaultKit
import SwiftUI
import UniformTypeIdentifiers

struct DocumentImportView: View {
    let vaultID: VaultID
    @ObservedObject var viewModel: DocumentImportViewModel

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Import Document")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { viewModel.cancel(vaultID: vaultID) }
                    }
                }
                .fileImporter(
                    isPresented: $viewModel.isFilePickerPresented,
                    allowedContentTypes: [.pdf, .jpeg, .png],
                    allowsMultipleSelection: false
                ) { result in
                    Task { await viewModel.handleFileSelection(result) }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            selectContent
        case .selected(let fileInfo):
            filePreview(fileInfo)
        case .importing(let fileInfo, let progress):
            VStack(spacing: 16) {
                filePreviewDetails(fileInfo)
                ProgressView(value: progress)
                Text("Encrypting and importing...")
                    .foregroundStyle(.secondary)
            }
            .padding()
        case .imported:
            ContentUnavailableView("Imported", systemImage: "checkmark.circle")
        case .failed(let message):
            ContentUnavailableView {
                Label("Import Failed", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Choose Another Document") { viewModel.chooseFile() }
            }
        }
    }

    private var selectContent: some View {
        ContentUnavailableView {
            Label("Choose a Document", systemImage: "doc.badge.plus")
        } description: {
            Text("PDF, JPG, JPEG, and PNG files are supported.")
        } actions: {
            Button("Select Document") { viewModel.chooseFile() }
        }
    }

    private func filePreview(_ fileInfo: DocumentImportFileInfo) -> some View {
        Form {
            Section("Selected File") {
                filePreviewDetails(fileInfo)
            }
            Section {
                Button("Import") {
                    Task { await viewModel.importSelectedFile(into: vaultID) }
                }
            }
        }
    }

    private func filePreviewDetails(_ fileInfo: DocumentImportFileInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(fileInfo.fileName, systemImage: "doc")
            Text(fileInfo.contentType)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(ByteCountFormatter.string(fromByteCount: fileInfo.originalSizeBytes, countStyle: .file))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
