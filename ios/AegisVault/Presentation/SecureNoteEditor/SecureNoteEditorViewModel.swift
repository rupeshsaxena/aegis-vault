import Combine
import Foundation
import SecureVaultKit

@MainActor
final class SecureNoteEditorViewModel: ObservableObject {
    @Published private(set) var state: SecureNoteEditorState = .idle
    @Published private(set) var data = SecureNoteEditorViewData()
    @Published private(set) var tagsInput = ""
    @Published private(set) var route: AppRoute?

    private let secureNoteService: any SecureNoteApplicationServicing
    private var mode: SecureNoteEditorMode?
    private var existingDetail: VaultObjectDetail?

    init(secureNoteService: any SecureNoteApplicationServicing) {
        self.secureNoteService = secureNoteService
    }

    func prepare(mode: SecureNoteEditorMode) async {
        guard self.mode != mode || state == .idle else { return }
        self.mode = mode
        data = SecureNoteEditorViewData()
        tagsInput = ""
        existingDetail = nil

        switch mode {
        case .create:
            state = .editing
        case .edit(let objectID):
            do {
                let detail = try await secureNoteService.loadNote(id: objectID)
                guard detail.type == .secureNote else {
                    state = .failed("This item cannot be edited as a secure note.")
                    return
                }
                existingDetail = detail
                data = SecureNoteEditorViewData(
                    title: detail.metadata.title,
                    content: detail.payload.notes ?? "",
                    tags: detail.metadata.tags
                )
                tagsInput = detail.metadata.tags.joined(separator: ", ")
                state = .editing
            } catch {
                state = .failed(Self.message(for: error))
            }
        }
    }

    func setTitle(_ value: String) {
        data.title = value
        restoreEditingState()
    }

    func setContent(_ value: String) {
        data.content = value
        restoreEditingState()
    }

    func setTagsInput(_ value: String) {
        tagsInput = value
        restoreEditingState()
    }

    func save() async {
        var input = data
        input.title = input.title.trimmingCharacters(in: .whitespacesAndNewlines)
        input.tags = parsedTags
        guard !input.title.isEmpty else {
            state = .failed("Title is required.")
            return
        }
        guard let mode else {
            state = .failed("Unable to save note.")
            return
        }

        state = .saving
        do {
            let objectID: VaultObjectID
            switch mode {
            case .create:
                objectID = try await secureNoteService.createNote(input)
            case .edit:
                guard let existingDetail else {
                    state = .failed("Unable to save note.")
                    return
                }
                objectID = try await secureNoteService.updateNote(existing: existingDetail, data: input)
            }
            state = .saved(objectID)
            route = .objectDetail(objectID)
        } catch {
            state = .failed(Self.message(for: error))
        }
    }

    func cancel() {
        switch mode {
        case .create(let vaultID): route = .vaultHome(vaultID)
        case .edit(let objectID): route = .objectDetail(objectID)
        case nil: break
        }
    }

    func clearRoute() {
        route = nil
    }

    private func restoreEditingState() {
        if case .failed = state {
            state = .editing
        }
    }

    private var parsedTags: [String] {
        var seen = Set<String>()
        return tagsInput
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }

    private static func message(for error: Error) -> String {
        if case VaultError.locked = error {
            return "Your vault is locked."
        }
        return "Unable to save note."
    }
}
