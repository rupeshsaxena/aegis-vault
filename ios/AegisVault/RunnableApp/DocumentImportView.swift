import Observation
import SecureVaultKit
import SwiftUI
import UniformTypeIdentifiers

protocol ImportDocumentUsing: Sendable {
    func execute(fileURL: URL, contentType: String, vaultID: VaultID) async throws -> DocumentImportResult
}

protocol LoadThumbnailUsing: Sendable {
    func execute(objectID: VaultObjectID) async throws -> VaultThumbnail
}

struct ImportDocumentUseCase: ImportDocumentUsing {
    let vaultEngine: any VaultEngine

    func execute(fileURL: URL, contentType: String, vaultID: VaultID) async throws -> DocumentImportResult {
        let accessed = fileURL.startAccessingSecurityScopedResource()
        defer { if accessed { fileURL.stopAccessingSecurityScopedResource() } }
        return try await vaultEngine.importDocument(
            DocumentImportInput(fileURL: fileURL, contentType: contentType),
            into: vaultID
        )
    }
}

struct LoadThumbnailUseCase: LoadThumbnailUsing {
    let vaultEngine: any VaultEngine

    func execute(objectID: VaultObjectID) async throws -> VaultThumbnail {
        try await vaultEngine.loadThumbnail(for: objectID)
    }
}

@MainActor
@Observable
final class DocumentImportViewModel {
    private(set) var selectedURL: URL?
    private(set) var selectedContentType: String?
    private(set) var isImporting = false
    private(set) var progress = 0.0
    private(set) var result: DocumentImportResult?
    private(set) var errorMessage: String?

    @ObservationIgnored private let importDocumentUseCase: any ImportDocumentUsing

    init(importDocumentUseCase: any ImportDocumentUsing) {
        self.importDocumentUseCase = importDocumentUseCase
    }

    func select(_ url: URL) {
        guard let contentType = Self.contentType(for: url.pathExtension) else {
            selectedURL = nil
            selectedContentType = nil
            errorMessage = "Choose a PDF, JPG, JPEG, or PNG file."
            return
        }
        selectedURL = url
        selectedContentType = contentType
        errorMessage = nil
    }

    func importSelected(into vaultID: VaultID) async {
        guard let selectedURL, let selectedContentType else {
            errorMessage = "Select a document to import."
            return
        }
        isImporting = true
        progress = 0.1
        errorMessage = nil
        defer { isImporting = false }
        do {
            result = try await importDocumentUseCase.execute(
                fileURL: selectedURL,
                contentType: selectedContentType,
                vaultID: vaultID
            )
            progress = 1
        } catch {
            progress = 0
            errorMessage = "Unable to import document."
        }
    }

    private static func contentType(for extensionName: String) -> String? {
        switch extensionName.lowercased() {
        case "pdf": "application/pdf"
        case "jpg", "jpeg": "image/jpeg"
        case "png": "image/png"
        default: nil
        }
    }
}

struct DocumentImportView: View {
    let vaultID: VaultID
    @State private var viewModel: DocumentImportViewModel
    @State private var isImporterPresented = false
    @Environment(\.dismiss) private var dismiss

    @MainActor
    init(vaultID: VaultID, importUseCase: any ImportDocumentUsing) {
        self.vaultID = vaultID
        _viewModel = State(initialValue: DocumentImportViewModel(importDocumentUseCase: importUseCase))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Document") {
                    Button("Select Document", systemImage: "doc.badge.plus") { isImporterPresented = true }
                    if let url = viewModel.selectedURL {
                        LabeledContent("Filename", value: url.lastPathComponent)
                        LabeledContent("Content Type", value: viewModel.selectedContentType ?? "Unknown")
                    }
                }
                if viewModel.isImporting {
                    Section("Importing") { ProgressView(value: viewModel.progress) }
                }
                if let errorMessage = viewModel.errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Import Document")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") { Task { await viewModel.importSelected(into: vaultID) } }
                        .disabled(viewModel.selectedURL == nil || viewModel.isImporting)
                }
            }
            .fileImporter(
                isPresented: $isImporterPresented,
                allowedContentTypes: [.pdf, .jpeg, .png],
                allowsMultipleSelection: false
            ) { selection in
                if case .success(let urls) = selection, let url = urls.first {
                    viewModel.select(url)
                } else {
                    viewModel.select(URL(fileURLWithPath: "unsupported"))
                }
            }
            .onChange(of: viewModel.result) { _, result in if result != nil { dismiss() } }
        }
    }
}
