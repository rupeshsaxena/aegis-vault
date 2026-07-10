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
    private var inspectTask: Task<Void, Never>?
    private var importTask: Task<Void, Never>?
    private var selectionRequestID = UUID()

    init(
        documentService: any DocumentApplicationServicing,
        errorMapper: any ErrorMapper = DefaultErrorMapper()
    ) {
        self.documentService = documentService
        self.errorMapper = errorMapper
    }

    deinit {
        inspectTask?.cancel()
        importTask?.cancel()
    }

    func chooseFile() {
        isFilePickerPresented = true
    }

    func handleFileSelection(_ result: Result<[URL], Error>) async {
        inspectTask?.cancel()
        importTask?.cancel()
        isFilePickerPresented = false
        let fileURL: URL
        do {
            guard let selectedURL = try result.get().first else {
                state = .failed("No document was selected.")
                return
            }
            fileURL = selectedURL
        } catch {
            selectedFileURL = nil
            state = .failed(userMessage(for: error))
            return
        }
        let requestID = beginSelectionRequest()
        let task = Task { [documentService] in
            do {
                let fileInfo = try await documentService.inspectDocument(fileURL: fileURL)
                try Task.checkCancellation()
                await MainActor.run {
                    guard self.selectionRequestID == requestID else { return }
                    self.selectedFileURL = fileURL
                    self.state = .selected(fileInfo)
                }
            } catch is CancellationError {
            } catch {
                await MainActor.run {
                    guard self.selectionRequestID == requestID else { return }
                    self.selectedFileURL = nil
                    self.state = .failed(self.userMessage(for: error))
                }
            }
        }
        inspectTask = task
        await task.value
    }

    func importSelectedFile(into vaultID: VaultID) async {
        importTask?.cancel()
        guard let selectedFileURL,
              case .selected(let fileInfo) = state else {
            state = .failed("Select a document to import.")
            return
        }

        state = .importing(fileInfo, progress: 0.1)
        let requestID = selectionRequestID
        let task = Task { [documentService] in
            do {
                let objectID = try await documentService.importDocument(
                    fileURL: selectedFileURL,
                    vaultID: vaultID
                )
                try Task.checkCancellation()
                await MainActor.run {
                    guard self.selectionRequestID == requestID else { return }
                    self.state = .imported(objectID)
                    self.route = .objectDetail(objectID)
                    self.selectedFileURL = nil
                    self.importTask = nil
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.importTask = nil
                }
            } catch {
                await MainActor.run {
                    guard self.selectionRequestID == requestID else { return }
                    self.state = .failed(self.userMessage(for: error))
                    self.importTask = nil
                }
            }
        }
        importTask = task
        await task.value
    }

    func cancel(vaultID: VaultID) {
        inspectTask?.cancel()
        importTask?.cancel()
        _ = beginSelectionRequest()
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

    private func beginSelectionRequest() -> UUID {
        let requestID = UUID()
        selectionRequestID = requestID
        return requestID
    }
}
