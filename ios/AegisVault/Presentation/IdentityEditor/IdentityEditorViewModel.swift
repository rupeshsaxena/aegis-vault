import Combine
import Foundation
import SecureVaultKit

@MainActor
final class IdentityEditorViewModel: ObservableObject {
    @Published private(set) var state: IdentityEditorState = .idle
    @Published private(set) var data = IdentityEditorViewData()
    @Published private(set) var tagsInput = ""
    @Published private(set) var route: AppRoute?

    private let identityService: any IdentityApplicationServicing
    private var mode: IdentityEditorMode?
    private var existingDetail: VaultObjectDetail?

    init(
        mode: IdentityEditorMode? = nil,
        identityService: any IdentityApplicationServicing
    ) {
        self.mode = mode
        self.identityService = identityService
        if case .create = mode {
            state = .editing
        }
    }

    func prepare(mode: IdentityEditorMode) async {
        guard self.mode != mode || state == .idle else { return }
        self.mode = mode
        data = IdentityEditorViewData()
        tagsInput = ""
        existingDetail = nil

        switch mode {
        case .create:
            state = .editing
        case .edit(let objectID):
            state = .idle
            do {
                let detail = try await identityService.loadIdentity(id: objectID)
                guard detail.type == .identity else {
                    state = .failed("This item cannot be edited as an identity.")
                    return
                }
                existingDetail = detail
                data = Self.editorData(from: detail)
                tagsInput = detail.metadata.tags.joined(separator: ", ")
                state = .editing
            } catch {
                state = .failed(Self.userMessage(for: error))
            }
        }
    }

    func setTitle(_ value: String) { update { $0.title = value } }
    func setIdentityType(_ value: IdentityDocumentType) { update { $0.identityType = value } }
    func setFullName(_ value: String) { update { $0.fullName = value } }
    func setDocumentNumber(_ value: String) { update { $0.documentNumber = value } }
    func setNotes(_ value: String) { update { $0.notes = value } }

    func setTagsInput(_ value: String) {
        tagsInput = value
        restoreEditingState()
    }

    func setIssueDateEnabled(_ enabled: Bool) {
        update { $0.issueDate = enabled ? ($0.issueDate ?? Date()) : nil }
    }

    func setIssueDate(_ value: Date) { update { $0.issueDate = value } }

    func setExpiryDateEnabled(_ enabled: Bool) {
        update { $0.expiryDate = enabled ? ($0.expiryDate ?? Date()) : nil }
    }

    func setExpiryDate(_ value: Date) { update { $0.expiryDate = value } }

    func save() async {
        var input = data
        input.tags = parsedTags

        guard let mode else {
            state = .failed("Unable to save identity.")
            return
        }

        state = .saving
        do {
            let objectID: VaultObjectID
            switch mode {
            case .create:
                objectID = try await identityService.createIdentity(input)
            case .edit:
                guard let existingDetail else {
                    state = .failed("Unable to save identity.")
                    return
                }
                objectID = try await identityService.updateIdentity(existing: existingDetail, data: input)
            }
            state = .saved(objectID)
            route = .objectDetail(objectID)
        } catch {
            state = .failed(Self.userMessage(for: error))
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

    static func userMessage(for error: Error) -> String {
        if case VaultError.locked = error {
            return "Your vault is locked."
        }
        if let serviceError = error as? ApplicationServiceError {
            return serviceError.userMessage
        }
        return "Unable to save identity."
    }

    private func update(_ mutation: (inout IdentityEditorViewData) -> Void) {
        mutation(&data)
        restoreEditingState()
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

    private static func editorData(from detail: VaultObjectDetail) -> IdentityEditorViewData {
        let fields = detail.payload.fields
        let typeRawValue: String?
        if case .text(let value) = fields["identityType"] {
            typeRawValue = value
        } else {
            typeRawValue = detail.metadata.category
        }

        let fullName: String
        if case .text(let value) = fields["fullName"] { fullName = value } else { fullName = "" }
        let documentNumber: String
        if case .secureText(let value) = fields["documentNumber"] { documentNumber = value } else { documentNumber = "" }
        let issueDate: Date?
        if case .date(let value) = fields["issueDate"] { issueDate = value } else { issueDate = nil }
        let expiryDate: Date?
        if case .date(let value) = fields["expiryDate"] { expiryDate = value } else { expiryDate = nil }

        return IdentityEditorViewData(
            title: detail.metadata.title,
            identityType: typeRawValue.flatMap(IdentityDocumentType.init(rawValue:)) ?? .other,
            fullName: fullName,
            documentNumber: documentNumber,
            issueDate: issueDate,
            expiryDate: expiryDate,
            notes: detail.payload.notes ?? "",
            tags: detail.metadata.tags
        )
    }
}
