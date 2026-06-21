import Combine
import Foundation
import SecureVaultKit

@MainActor
final class DocumentImportViewModel: ObservableObject {
    @Published private(set) var state: DocumentImportState = .idle
    @Published var isFilePickerPresented = false
    @Published private(set) var route: AppRoute?

    private let importDocumentUseCase: any ImportDocumentUsing
    private var selectedFileURL: URL?

    init(importDocumentUseCase: any ImportDocumentUsing) {
        self.importDocumentUseCase = importDocumentUseCase
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
            let fileInfo = try await importDocumentUseCase.inspect(fileURL: fileURL)
            selectedFileURL = fileURL
            state = .selected(fileInfo)
        } catch {
            selectedFileURL = nil
            state = .failed(Self.userMessage(for: error))
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
            let objectID = try await importDocumentUseCase.execute(
                fileURL: selectedFileURL,
                vaultID: vaultID
            )
            state = .imported(objectID)
            route = .objectDetail(objectID)
            self.selectedFileURL = nil
        } catch {
            state = .failed(Self.userMessage(for: error))
        }
    }

    func cancel(vaultID: VaultID) {
        selectedFileURL = nil
        route = .vaultHome(vaultID)
    }

    func clearRoute() {
        route = nil
    }

    static func userMessage(for error: Error) -> String {
        switch error {
        case VaultError.locked:
            "Your vault is locked."
        case VaultError.unsupported, VaultError.unsupportedOperation:
            "This file type is not supported."
        case VaultError.invalidInput:
            "Unable to read the selected document."
        default:
            "Unable to import document."
        }
    }
}
