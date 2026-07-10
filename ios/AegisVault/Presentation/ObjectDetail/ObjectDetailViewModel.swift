import Combine
import Foundation
import SecureVaultKit

@MainActor
final class ObjectDetailViewModel: ObservableObject {
    @Published private(set) var state: ObjectDetailState = .idle
    @Published private(set) var route: AppRoute?
    @Published private(set) var thumbnailState: ThumbnailViewState = .idle

    private let getObjectDetailUseCase: any GetObjectDetailUsing
    private let moveObjectToTrashUseCase: any MoveObjectToTrashUsing
    private let loadThumbnailUseCase: any LoadThumbnailUsing
    private let errorMapper: any ErrorMapper
    private let thumbnailRequestCoordinator: ThumbnailRequestCoordinator
    private var objectID: VaultObjectID?
    private var objectType: VaultObjectType?
    private var secureFieldValues: [String: String] = [:]
    private var loadTask: Task<Void, Never>?
    private var thumbnailTask: Task<Void, Never>?
    private var loadRequestID = UUID()

    init(
        getObjectDetailUseCase: any GetObjectDetailUsing,
        moveObjectToTrashUseCase: any MoveObjectToTrashUsing,
        loadThumbnailUseCase: any LoadThumbnailUsing,
        errorMapper: any ErrorMapper = DefaultErrorMapper(),
        thumbnailRequestCoordinator: ThumbnailRequestCoordinator = ThumbnailRequestCoordinator()
    ) {
        self.getObjectDetailUseCase = getObjectDetailUseCase
        self.moveObjectToTrashUseCase = moveObjectToTrashUseCase
        self.loadThumbnailUseCase = loadThumbnailUseCase
        self.errorMapper = errorMapper
        self.thumbnailRequestCoordinator = thumbnailRequestCoordinator
    }

    deinit {
        loadTask?.cancel()
        thumbnailTask?.cancel()
    }

    func loadObject(id: VaultObjectID) async {
        loadTask?.cancel()
        thumbnailTask?.cancel()
        let requestID = beginLoadRequest()
        state = .loading
        objectID = id
        secureFieldValues.removeAll(keepingCapacity: false)
        thumbnailState = .idle

        let task = Task { [getObjectDetailUseCase] in
            do {
                let detail = try await getObjectDetailUseCase.execute(id: id)
                try Task.checkCancellation()
                await MainActor.run {
                    guard self.loadRequestID == requestID,
                          self.objectID == id else { return }
                    self.objectType = detail.type
                    self.state = .loaded(self.makeViewData(from: detail))
                }
            } catch is CancellationError {
            } catch {
                await MainActor.run {
                    guard self.loadRequestID == requestID,
                          self.objectID == id else { return }
                    self.state = .failed(self.userMessage(for: error, action: .load))
                }
            }
        }
        loadTask = task
        await task.value
    }

    func toggleSecureField(id: String) {
        guard case .loaded(var detail) = state,
              let index = detail.fields.firstIndex(where: { $0.id == id }),
              detail.fields[index].isSensitive,
              let secureValue = secureFieldValues[id] else {
            return
        }

        let shouldReveal = !detail.fields[index].isRevealed
        detail.fields[index].isRevealed = shouldReveal
        detail.fields[index].value = shouldReveal ? secureValue : Self.hiddenValue
        state = .loaded(detail)
    }

    func edit() {
        guard let objectID else { return }
        switch objectType {
        case .secureNote:
            route = .secureNoteEditor(.edit(objectID))
        case .identity:
            route = .identityEditor(.edit(objectID))
        case .card:
            route = .cardEditor(.edit(objectID))
        default:
            route = .objectEditor(objectID)
        }
    }

    func clearRoute() {
        route = nil
    }

    func clearSensitivePresentationState() {
        thumbnailTask?.cancel()
        secureFieldValues.removeAll(keepingCapacity: false)
        thumbnailState = .placeholder

        guard case .loaded(var detail) = state else { return }
        for index in detail.fields.indices where detail.fields[index].isSensitive {
            detail.fields[index].isRevealed = false
            detail.fields[index].value = Self.hiddenValue
        }
        state = .loaded(detail)
    }

    func loadThumbnail(for objectId: VaultObjectID) async {
        if let thumbnailTask {
            await thumbnailTask.value
            return
        }
        guard thumbnailState == .idle else { return }
        let expectedObjectID = self.objectID
        thumbnailState = .loading
        let task = Task { [loadThumbnailUseCase, thumbnailRequestCoordinator] in
            do {
                let thumbnail = try await thumbnailRequestCoordinator.thumbnail(for: objectId) {
                    try await loadThumbnailUseCase.execute(objectId: objectId)
                }
                try Task.checkCancellation()
                await MainActor.run {
                    guard expectedObjectID == nil || self.objectID == objectId else { return }
                    self.thumbnailState = .loaded(
                        ThumbnailViewData(data: thumbnail.data, contentType: thumbnail.contentType)
                    )
                    self.thumbnailTask = nil
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.thumbnailTask = nil
                }
            } catch {
                await MainActor.run {
                    guard expectedObjectID == nil || self.objectID == objectId else { return }
                    self.thumbnailState = .placeholder
                    self.thumbnailTask = nil
                }
            }
        }
        thumbnailTask = task
        await task.value
    }

    func moveToTrash(vaultID: VaultID? = nil) async {
        guard let objectID else {
            state = .failed("Unable to move this item to Trash.")
            return
        }

        do {
            try await moveObjectToTrashUseCase.execute(id: objectID)
            secureFieldValues.removeAll(keepingCapacity: false)
            thumbnailState = .placeholder
            state = .movedToTrash
            if let vaultID {
                route = .trash(vaultID)
            }
        } catch {
            secureFieldValues.removeAll(keepingCapacity: false)
            state = .failed(userMessage(for: error, action: .trash))
        }
    }

    private func beginLoadRequest() -> UUID {
        let requestID = UUID()
        loadRequestID = requestID
        return requestID
    }

    private func userMessage(for error: Error, action: FailureAction) -> String {
        errorMapper.userMessage(for: error, fallback: fallbackMessage(for: action)).message
    }

    private func fallbackMessage(for action: FailureAction) -> UserMessage {
        switch action {
        case .load:
            UserMessage(title: "Unable to Load Item", message: "Unable to load this item.")
        case .trash:
            UserMessage(title: "Unable to Move Item", message: "Unable to move this item to Trash.")
        }
    }

    enum FailureAction {
        case load
        case trash
    }

    private func makeViewData(from detail: VaultObjectDetail) -> ObjectDetailViewData {
        var fields = detail.payload.fields
            .sorted { $0.key < $1.key }
            .map { makeField(key: $0.key, value: $0.value) }
        if let notes = detail.payload.notes, !notes.isEmpty {
            fields.insert(field(id: "notes", label: "Note", value: notes), at: 0)
        }

        return ObjectDetailViewData(
            id: detail.id,
            title: detail.metadata.title,
            type: detail.type,
            subtitle: detail.metadata.subtitle,
            category: detail.metadata.category,
            tags: detail.metadata.tags,
            isFavorite: detail.metadata.isFavorite,
            fields: fields,
            attachments: detail.payload.attachments.map {
                ObjectDetailAttachmentViewData(
                    id: $0.id,
                    fileName: $0.fileName,
                    role: $0.role,
                    contentType: $0.contentType,
                    byteCount: $0.byteCount
                )
            },
            createdAt: detail.metadata.createdAt,
            updatedAt: detail.metadata.updatedAt,
            version: detail.version
        )
    }

    private func makeField(key: String, value: VaultFieldValue) -> ObjectDetailFieldViewData {
        let label = key.replacingOccurrences(of: "_", with: " ").capitalized

        switch value {
        case .secureText(let value):
            secureFieldValues[key] = value
            return ObjectDetailFieldViewData(
                id: key,
                label: label,
                value: Self.hiddenValue,
                isSensitive: true,
                isRevealed: false
            )
        case .text(let value), .url(let value), .email(let value), .phone(let value):
            return field(id: key, label: label, value: value)
        case .number(let value):
            return field(id: key, label: label, value: value.formatted())
        case .boolean(let value):
            return field(id: key, label: label, value: value ? "Yes" : "No")
        case .date(let value):
            return field(id: key, label: label, value: value.formatted(date: .abbreviated, time: .omitted))
        }
    }

    private func field(id: String, label: String, value: String) -> ObjectDetailFieldViewData {
        ObjectDetailFieldViewData(
            id: id,
            label: label,
            value: value,
            isSensitive: false,
            isRevealed: true
        )
    }

    private static let hiddenValue = "••••••••"
}
