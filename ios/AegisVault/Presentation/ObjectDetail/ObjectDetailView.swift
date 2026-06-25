import SecureVaultKit
import SwiftUI
import UIKit

struct ObjectDetailView: View {
    let objectID: VaultObjectID
    let vaultID: VaultID?
    @ObservedObject var viewModel: ObjectDetailViewModel

    var body: some View {
        NavigationStack {
            content
                .navigationBarTitleDisplayMode(.large)
                .toolbar { toolbarItems }
                .task { await viewModel.loadObject(id: objectID) }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading, .idle:
            ProgressView()
        case .loaded(let detail):
            detailView(detail)
        case .failed(let message):
            ContentUnavailableView(
                "Unable to Load",
                systemImage: "exclamationmark.circle",
                description: Text(message)
            )
        case .movedToTrash:
            ContentUnavailableView("Moved to Trash", systemImage: "trash")
        }
    }

    @ViewBuilder
    private func detailView(_ detail: ObjectDetailViewData) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if detail.type == .document || detail.type == .photo {
                    thumbnailSection
                }
                if !detail.fields.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(detail.fields) { field in
                            fieldRow(field)
                        }
                    }
                    .padding(.horizontal)
                }
                if !detail.tags.isEmpty {
                    Text(detail.tags.joined(separator: ", "))
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(detail.title)
        .accessibilityIdentifier("objectDetailView")
    }

    @ViewBuilder
    private var thumbnailSection: some View {
        switch viewModel.thumbnailState {
        case .loaded(let thumbnail):
            if let image = UIImage(data: thumbnail.data) {
                Image(uiImage: image)
                    .resizable().scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 220)
                    .padding(.horizontal)
                    .accessibilityIdentifier("detailThumbnail")
            } else {
                ContentUnavailableView("Preview generated", systemImage: "doc.richtext.fill")
                    .accessibilityIdentifier("detailThumbnail")
            }
        case .loading:
            ProgressView().frame(maxHeight: 220)
        default:
            ContentUnavailableView("Preview unavailable", systemImage: "doc")
                .accessibilityIdentifier("detailThumbnailPlaceholder")
        }
    }

    private func fieldRow(_ field: ObjectDetailFieldViewData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(field.label)
                .font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
            HStack {
                Text(field.value)
                    .privacySensitive()
                    .accessibilityIdentifier("fieldValue-\(field.id)")
                Spacer()
                if field.isSensitive {
                    Button(field.isRevealed ? "Hide" : "Reveal") {
                        viewModel.toggleSecureField(id: field.id)
                    }
                    .accessibilityIdentifier("reveal-\(field.id)")
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("Edit") { viewModel.edit() }
                    .accessibilityIdentifier("editObjectButton")
                Divider()
                Button("Move to Trash", role: .destructive) {
                    Task { await viewModel.moveToTrash(vaultID: vaultID) }
                }
                .accessibilityIdentifier("moveToTrashButton")
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityIdentifier("objectOptionsMenu")
        }
    }
}
