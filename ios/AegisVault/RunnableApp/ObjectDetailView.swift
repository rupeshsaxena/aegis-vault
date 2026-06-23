import Observation
import SecureVaultKit
import SwiftUI

// MARK: - View Model

@MainActor
@Observable
final class ObjectDetailViewModel {
    private(set) var detail: VaultObjectDetail?
    private(set) var isLoading = false
    private(set) var isMovedToTrash = false
    private(set) var errorMessage: String?
    private(set) var revealedSecureFields: Set<String> = []

    @ObservationIgnored private let objectID: VaultObjectID
    @ObservationIgnored private let getDetailUseCase: any GetObjectDetailUsing
    @ObservationIgnored private let moveToTrashUseCase: any MoveObjectToTrashUsing

    init(
        objectID: VaultObjectID,
        getDetailUseCase: any GetObjectDetailUsing,
        moveToTrashUseCase: any MoveObjectToTrashUsing
    ) {
        self.objectID = objectID
        self.getDetailUseCase = getDetailUseCase
        self.moveToTrashUseCase = moveToTrashUseCase
    }

    func loadDetail() async {
        isLoading = true
        errorMessage = nil
        do {
            detail = try await getDetailUseCase.execute(id: objectID)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
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
        switch value {
        case .secureText(let text): revealedSecureFields.contains(key) ? text : "••••••••"
        case .text(let text), .url(let text), .email(let text), .phone(let text): text
        case .number(let number): number.formatted()
        case .boolean(let boolean): boolean ? "Yes" : "No"
        case .date(let date): date.formatted(date: .abbreviated, time: .omitted)
        }
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
            moveToTrashUseCase: flow.moveToTrash
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
                    Button("Edit") { showEditSheet = true }
                        .accessibilityIdentifier("editObjectButton")
                    Divider()
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
            }
            .padding(.vertical)
        }
        .accessibilityIdentifier("objectDetailView")
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
            "issuer": "Issuer"
        ]
        return labels[key] ?? "Field"
    }
}
