import SecureVaultKit
import SwiftUI
import UniformTypeIdentifiers

struct DocumentImportView: View {
    let vaultID: VaultID
    @ObservedObject var viewModel: DocumentImportViewModel

    var body: some View {
        NavigationStack {
            form
                .navigationTitle("Import Document")
                .toolbar { toolbarItems }
        }
        .fileImporter(
            isPresented: $viewModel.isFilePickerPresented,
            allowedContentTypes: [.pdf, .jpeg, .png],
            allowsMultipleSelection: false
        ) { result in
            Task { await viewModel.handleFileSelection(result) }
        }
    }

    @ViewBuilder
    private var form: some View {
        Form {
            Section("Document") {
                Button("Select Document", systemImage: "doc.badge.plus") {
                    viewModel.chooseFile()
                }
                if case .selected(let fileInfo) = viewModel.state {
                    LabeledContent("Filename", value: fileInfo.fileName)
                    LabeledContent("Content Type", value: fileInfo.contentType)
                    LabeledContent("Size", value: ByteCountFormatter.string(
                        fromByteCount: fileInfo.originalSizeBytes,
                        countStyle: .file
                    ))
                }
            }
            if case .importing(_, let progress) = viewModel.state {
                Section("Importing") {
                    ProgressView(value: progress)
                }
            }
            if case .failed(let message) = viewModel.state {
                Section {
                    Text(message).foregroundStyle(.red)
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { viewModel.cancel(vaultID: vaultID) }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Import") {
                Task { await viewModel.importSelectedFile(into: vaultID) }
            }
            .disabled(!canImport)
        }
    }

    private var canImport: Bool {
        switch viewModel.state {
        case .selected: return true
        default: return false
        }
    }
}
