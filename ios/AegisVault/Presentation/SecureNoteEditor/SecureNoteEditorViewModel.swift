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
    private let errorMapper: any ErrorMapper
    private var mode: SecureNoteEditorMode?
    private var existingDetail: VaultObjectDetail?
    private var prepareTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?
    private var prepareRequestID = UUID()

    init(
        secureNoteService: any SecureNoteApplicationServicing,
        errorMapper: any ErrorMapper = DefaultErrorMapper()
    ) {
        self.secureNoteService = secureNoteService
        self.errorMapper = errorMapper
    }

    deinit {
        prepareTask?.cancel()
        saveTask?.cancel()
    }

    func prepare(mode: SecureNoteEditorMode) async {
        guard self.mode != mode || state == .idle else { return }
        prepareTask?.cancel()
        saveTask?.cancel()
        let requestID = beginPrepareRequest()
        self.mode = mode
        data = SecureNoteEditorViewData()
        tagsInput = ""
        existingDetail = nil

        switch mode {
        case .create:
            state = .editing
        case .edit(let objectID):
            let task = Task { [secureNoteService] in
                do {
                    let detail = try await secureNoteService.loadNote(id: objectID)
                    try Task.checkCancellation()
                    await MainActor.run {
                        guard self.prepareRequestID == requestID else { return }
                        guard detail.type == .secureNote else {
                            self.state = .failed("This item cannot be edited as a secure note.")
                            return
                        }
                        self.existingDetail = detail
                        self.data = SecureNoteEditorViewData(
                            title: detail.metadata.title,
                            content: detail.payload.notes ?? "",
                            tags: detail.metadata.tags
                        )
                        self.tagsInput = detail.metadata.tags.joined(separator: ", ")
                        self.state = .editing
                    }
                } catch is CancellationError {
                } catch {
                    await MainActor.run {
                        guard self.prepareRequestID == requestID else { return }
                        self.state = .failed(self.message(for: error))
                    }
                }
            }
            prepareTask = task
            await task.value
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
        saveTask?.cancel()
        var input = data
        input.tags = parsedTags
        guard let mode else {
            state = .failed("Unable to save note.")
            return
        }

        state = .saving
        let existingDetail = self.existingDetail
        let task = Task { [secureNoteService] in
            do {
                let objectID: VaultObjectID
                switch mode {
                case .create:
                    objectID = try await secureNoteService.createNote(input)
                case .edit:
                    guard let existingDetail else {
                        await MainActor.run {
                            self.state = .failed("Unable to save note.")
                        }
                        return
                    }
                    objectID = try await secureNoteService.updateNote(existing: existingDetail, data: input)
                }
                try Task.checkCancellation()
                await MainActor.run {
                    self.state = .saved(objectID)
                    self.route = .objectDetail(objectID)
                    self.saveTask = nil
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.saveTask = nil
                }
            } catch {
                await MainActor.run {
                    self.state = .failed(self.message(for: error))
                    self.saveTask = nil
                }
            }
        }
        saveTask = task
        await task.value
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

    private func message(for error: Error) -> String {
        errorMapper.userMessage(
            for: error,
            fallback: UserMessage(title: "Unable to Save Note", message: "Unable to save note.")
        ).message
    }

    private func beginPrepareRequest() -> UUID {
        let requestID = UUID()
        prepareRequestID = requestID
        return requestID
    }
}
