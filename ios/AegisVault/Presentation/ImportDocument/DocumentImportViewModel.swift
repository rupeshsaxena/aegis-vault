import Combine
import Foundation
import SecureVaultKit

@MainActor
final class DocumentImportViewModel: ObservableObject {
    @Published private(set) var state: DocumentImportState = .idle
    @Published var isFilePickerPresented = false
    @Published private(set) var route: AppRoute?

    private let documentService: any DocumentApplicationServicing
    private let errorMapper: any ErrorMapper
    private var selectedFileURL: URL?

    init(
        documentService: any DocumentApplicationServicing,
        errorMapper: any ErrorMapper = DefaultErrorMapper()
    ) {
        self.documentService = documentService
        self.errorMapper = errorMapper
    }

    func chooseFile() {
        isFilePickerPresented = true
    }

    func handleFileSelection(_ result: Result<[URL], Error>) async {
        isFilePickerPresented = false
        do {
            guard let fileURL = try result.get().first else {
                state = .failed("No document was selected.")
                return
            }
            let fileInfo = try await documentService.inspectDocument(fileURL: fileURL)
            selectedFileURL = fileURL
            state = .selected(fileInfo)
        } catch {
            selectedFileURL = nil
            state = .failed(userMessage(for: error))
        }
    }

    func importSelectedFile(into vaultID: VaultID) async {
        guard let selectedFileURL,
              case .selected(let fileInfo) = state else {
            state = .failed("Select a document to import.")
            return
        }

        state = .importing(fileInfo, progress: 0.1)
        do {
            let objectID = try await documentService.importDocument(
                fileURL: selectedFileURL,
                vaultID: vaultID
            )
            state = .imported(objectID)
            route = .objectDetail(objectID)
            self.selectedFileURL = nil
        } catch {
            state = .failed(userMessage(for: error))
        }
    }

    func cancel(vaultID: VaultID) {
        selectedFileURL = nil
        route = .vaultHome(vaultID)
    }

    func clearRoute() {
        route = nil
    }

    private func userMessage(for error: Error) -> String {
        errorMapper.userMessage(
            for: error,
            fallback: UserMessage(title: "Import Failed", message: "Unable to import document.")
        ).message
    }
}
