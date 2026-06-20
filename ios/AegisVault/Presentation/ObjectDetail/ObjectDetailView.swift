import SecureVaultKit
import SwiftUI

struct ObjectDetailView: View {
    let objectID: VaultObjectID
    @ObservedObject var viewModel: ObjectDetailViewModel

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Item Details")
                .toolbar {
                    if case .loaded = viewModel.state {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                viewModel.edit()
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                        }
                    }
                }
                .task(id: objectID) {
                    await viewModel.loadObject(id: objectID)
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView()
        case .loaded(let detail):
            detailContent(detail)
        case .failed(let message):
            ContentUnavailableView {
                Label("Unable to Load Item", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") {
                    Task { await viewModel.loadObject(id: objectID) }
                }
            }
        case .movedToTrash:
            ContentUnavailableView(
                "Moved to Trash",
                systemImage: "trash",
                description: Text("This item is no longer shown in your vault.")
            )
        }
    }

    private func detailContent(_ detail: ObjectDetailViewData) -> some View {
        List {
            Section {
                LabeledContent("Title", value: detail.title)
                LabeledContent("Type", value: displayName(for: detail.type))
                if let subtitle = detail.subtitle, !subtitle.isEmpty {
                    LabeledContent("Subtitle", value: subtitle)
                }
                if !detail.tags.isEmpty {
                    LabeledContent("Tags", value: detail.tags.joined(separator: ", "))
                }
                LabeledContent("Favorite", value: detail.isFavorite ? "Yes" : "No")
            } header: {
                Text("Metadata")
            }

            if !detail.fields.isEmpty {
                Section("Fields") {
                    ForEach(detail.fields) { field in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(field.label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(field.value)
                                    .textSelection(.enabled)
                            }
                            Spacer()
                            if field.isSensitive {
                                Button {
                                    viewModel.toggleSecureField(id: field.id)
                                } label: {
                                    Image(systemName: field.isRevealed ? "eye.slash" : "eye")
                                }
                                .accessibilityLabel(field.isRevealed ? "Hide value" : "Reveal value")
                            }
                        }
                    }
                }
            }

            Section("Attachments") {
                if detail.attachments.isEmpty {
                    Text("No attachments")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(detail.attachments) { attachment in
                        HStack(spacing: 12) {
                            Image(systemName: "paperclip")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(attachment.fileName)
                                Text("\(attachment.role.rawValue.capitalized) · \(attachment.byteCount.formatted()) bytes")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section("History") {
                LabeledContent("Created", value: detail.createdAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Updated", value: detail.updatedAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Version", value: detail.version.formatted())
            }

            Section {
                Button(role: .destructive) {
                    Task { await viewModel.moveToTrash() }
                } label: {
                    Label("Move to Trash", systemImage: "trash")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func displayName(for type: VaultObjectType) -> String {
        switch type {
        case .secureNote: "Secure Note"
        case .identity: "Identity"
        case .card: "Card"
        case .document: "Document"
        case .photo: "Photo"
        }
    }
}
