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
    private var objectID: VaultObjectID?
    private var objectType: VaultObjectType?
    private var secureFieldValues: [String: String] = [:]

    init(
        getObjectDetailUseCase: any GetObjectDetailUsing,
        moveObjectToTrashUseCase: any MoveObjectToTrashUsing,
        loadThumbnailUseCase: any LoadThumbnailUsing
    ) {
        self.getObjectDetailUseCase = getObjectDetailUseCase
        self.moveObjectToTrashUseCase = moveObjectToTrashUseCase
        self.loadThumbnailUseCase = loadThumbnailUseCase
    }

    func loadObject(id: VaultObjectID) async {
        state = .loading
        objectID = id
        secureFieldValues.removeAll(keepingCapacity: false)
        thumbnailState = .idle

        do {
            let detail = try await getObjectDetailUseCase.execute(id: id)
            objectType = detail.type
            state = .loaded(makeViewData(from: detail))
        } catch {
            state = .failed(Self.userMessage(for: error, action: .load))
        }
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

    func loadThumbnail(for objectId: VaultObjectID) async {
        guard thumbnailState == .idle else { return }
        thumbnailState = .loading
        do {
            let thumbnail = try await loadThumbnailUseCase.execute(objectId: objectId)
            thumbnailState = .loaded(
                ThumbnailViewData(data: thumbnail.data, contentType: thumbnail.contentType)
            )
        } catch {
            thumbnailState = .placeholder
        }
    }

    func moveToTrash() async {
        guard let objectID else {
            state = .failed("Unable to move this item to Trash.")
            return
        }

        do {
            try await moveObjectToTrashUseCase.execute(id: objectID)
            secureFieldValues.removeAll(keepingCapacity: false)
            thumbnailState = .placeholder
            state = .movedToTrash
        } catch {
            secureFieldValues.removeAll(keepingCapacity: false)
            state = .failed(Self.userMessage(for: error, action: .trash))
        }
    }

    static func userMessage(for error: Error, action: FailureAction) -> String {
        switch error {
        case VaultError.locked:
            return "Your vault is locked."
        case VaultError.objectNotFound:
            return "This item could not be found."
        default:
            switch action {
            case .load: return "Unable to load this item."
            case .trash: return "Unable to move this item to Trash."
            }
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
