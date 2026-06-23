import Observation
import SecureVaultKit
import SwiftUI
import UIKit

// MARK: - View Model

@MainActor
@Observable
final class ObjectDetailViewModel {
    private(set) var detail: VaultObjectDetail?
    private(set) var isLoading = false
    private(set) var isMovedToTrash = false
    private(set) var errorMessage: String?
    private(set) var revealedSecureFields: Set<String> = []
    private(set) var thumbnailData: Data?
    private(set) var thumbnailUnavailable = false

    @ObservationIgnored private let objectID: VaultObjectID
    @ObservationIgnored private let getDetailUseCase: any GetObjectDetailUsing
    @ObservationIgnored private let moveToTrashUseCase: any MoveObjectToTrashUsing
    @ObservationIgnored private let loadThumbnailUseCase: any LoadThumbnailUsing

    init(
        objectID: VaultObjectID,
        getDetailUseCase: any GetObjectDetailUsing,
        moveToTrashUseCase: any MoveObjectToTrashUsing,
        loadThumbnailUseCase: any LoadThumbnailUsing = UnavailableThumbnailUseCase()
    ) {
        self.objectID = objectID
        self.getDetailUseCase = getDetailUseCase
        self.moveToTrashUseCase = moveToTrashUseCase
        self.loadThumbnailUseCase = loadThumbnailUseCase
    }

    func loadDetail() async {
        isLoading = true
        errorMessage = nil
        do {
            detail = try await getDetailUseCase.execute(id: objectID)
            if detail?.type == .document || detail?.type == .photo {
                await loadThumbnail()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func loadThumbnail() async {
        do {
            thumbnailData = try await loadThumbnailUseCase.execute(objectId: objectID).data
            thumbnailUnavailable = false
        } catch {
            thumbnailData = nil
            thumbnailUnavailable = true
        }
    }

    func moveToTrash() async {
        do {
            try await moveToTrashUseCase.execute(id: objectID)
            isMovedToTrash = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleReveal(field key: String) {
        if revealedSecureFields.contains(key) {
            revealedSecureFields.remove(key)
        } else {
            revealedSecureFields.insert(key)
        }
    }

    func displayedValue(for key: String, value: VaultFieldValue) -> String {
        if key == "originalSizeBytes", case .number(let number) = value {
            return ByteCountFormatter.string(fromByteCount: Int64(number), countStyle: .file)
        }
        switch value {
        case .secureText(let text): return revealedSecureFields.contains(key) ? text : "••••••••"
        case .text(let text), .url(let text), .email(let text), .phone(let text): return text
        case .number(let number): return number.formatted()
        case .boolean(let boolean): return boolean ? "Yes" : "No"
        case .date(let date): return date.formatted(date: .abbreviated, time: .omitted)
        }
    }
}

private struct UnavailableThumbnailUseCase: LoadThumbnailUsing {
    func execute(objectId: VaultObjectID) async throws -> VaultThumbnail {
        throw VaultError.thumbnailNotFound(objectId)
    }
}

// MARK: - View

struct ObjectDetailView: View {
    let flow: VaultHomeFlowUseCases
    let onMovedToTrash: () -> Void
    @State private var viewModel: ObjectDetailViewModel
    @State private var showEditSheet = false
    @Environment(\.dismiss) private var dismiss

    @MainActor init(
        objectID: VaultObjectID,
        flow: VaultHomeFlowUseCases,
        onMovedToTrash: @escaping () -> Void
    ) {
        self.flow = flow
        self.onMovedToTrash = onMovedToTrash
        _viewModel = State(initialValue: ObjectDetailViewModel(
            objectID: objectID,
            getDetailUseCase: flow.getDetail,
            moveToTrashUseCase: flow.moveToTrash,
            loadThumbnailUseCase: flow.loadThumbnail
        ))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else if let detail = viewModel.detail {
                detailContent(detail)
            } else if let error = viewModel.errorMessage {
                ContentUnavailableView(
                    "Unable to Load",
                    systemImage: "exclamationmark.circle",
                    description: Text(error)
                )
            }
        }
        .navigationTitle(viewModel.detail?.metadata.title ?? "Note")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if viewModel.detail?.type != .document && viewModel.detail?.type != .photo {
                        Button("Edit") { showEditSheet = true }
                            .accessibilityIdentifier("editObjectButton")
                        Divider()
                    }
                    Button("Move to Trash", role: .destructive) {
                        Task { await viewModel.moveToTrash() }
                    }
                    .accessibilityIdentifier("moveToTrashButton")
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityIdentifier("objectOptionsMenu")
            }
        }
        .task { await viewModel.loadDetail() }
        .sheet(isPresented: $showEditSheet, onDismiss: {
            Task { await viewModel.loadDetail() }
        }) {
            if let detail = viewModel.detail {
                switch detail.type {
                case .identity:
                    IdentityEditorView(
                        mode: .edit(detail),
                        createUseCase: flow.createIdentity,
                        updateUseCase: flow.updateIdentity
                    )
                case .card:
                    CardEditorView(
                        mode: .edit(detail),
                        createUseCase: flow.createCard,
                        updateUseCase: flow.updateCard
                    )
                default:
                SecureNoteEditorView(
                    mode: .edit(detail),
                    createUseCase: flow.createNote,
                    updateUseCase: flow.updateNote
                )
                }
            }
        }
        .onChange(of: viewModel.isMovedToTrash) { _, moved in
            if moved {
                onMovedToTrash()
                dismiss()
            }
        }
    }

    @ViewBuilder
    private func detailContent(_ detail: VaultObjectDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if detail.type == .document || detail.type == .photo {
                    detailThumbnail
                        .padding(.horizontal)
                }
                if !detail.payload.fields.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(detail.payload.fields.keys.sorted(), id: \.self) { key in
                            if let value = detail.payload.fields[key] {
                                fieldRow(key: key, value: value)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                if let notes = detail.payload.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Text(notes)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("noteContent")
                    }
                    .padding(.horizontal)
                } else if detail.payload.fields.isEmpty {
                    ContentUnavailableView(
                        "No Content",
                        systemImage: "note.text",
                        description: Text("This note has no content.")
                    )
                }
                if !detail.payload.attachments.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Attachments")
                            .font(.headline)
                        ForEach(detail.payload.attachments, id: \.attachmentId) { attachment in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(attachment.fileName)
                                Text(attachment.contentType)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(ByteCountFormatter.string(
                                    fromByteCount: Int64(attachment.originalSizeBytes),
                                    countStyle: .file
                                ))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .accessibilityIdentifier("objectDetailView")
    }

    @ViewBuilder
    private var detailThumbnail: some View {
        if let data = viewModel.thumbnailData {
            if let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 220)
                    .accessibilityIdentifier("detailThumbnail")
            } else {
                ContentUnavailableView("Thumbnail generated", systemImage: "doc.richtext.fill")
                    .accessibilityIdentifier("detailThumbnail")
            }
        } else {
            ContentUnavailableView("Preview unavailable", systemImage: "doc")
                .accessibilityIdentifier("detailThumbnailPlaceholder")
        }
    }

    private func fieldRow(key: String, value: VaultFieldValue) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(safeLabel(for: key))
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Text(viewModel.displayedValue(for: key, value: value))
                    .privacySensitive()
                    .accessibilityIdentifier("fieldValue-\(key)")
                Spacer()
                if case .secureText = value {
                    Button(viewModel.revealedSecureFields.contains(key) ? "Hide" : "Reveal") {
                        viewModel.toggleReveal(field: key)
                    }
                    .accessibilityIdentifier("reveal-\(key)")
                }
            }
        }
    }

    private func safeLabel(for key: String) -> String {
        let labels = [
            "identityType": "Identity Type",
            "fullName": "Full Name",
            "documentNumber": "Document Number",
            "issueDate": "Issue Date",
            "expiryDate": "Expiry Date",
            "cardType": "Card Type",
            "cardholderName": "Cardholder Name",
            "cardNumber": "Card Number",
            "expiryMonth": "Expiry Month",
            "expiryYear": "Expiry Year",
            "issuer": "Issuer",
            "fileName": "Filename",
            "contentType": "Content Type",
            "originalSizeBytes": "File Size",
            "importedAt": "Imported"
        ]
        return labels[key] ?? "Field"
    }
}
