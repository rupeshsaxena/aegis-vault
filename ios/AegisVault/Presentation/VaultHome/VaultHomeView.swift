import SecureVaultKit
import SwiftUI

struct VaultHomeView: View {
    let vaultID: VaultID
    @ObservedObject var viewModel: VaultHomeViewModel
    let navigate: (AppRoute) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.state.phase == .loading {
                    ProgressView()
                } else if viewModel.state.objects.isEmpty {
                    ContentUnavailableView(
                        "No Items",
                        systemImage: "tray",
                        description: Text("Your vault is empty.")
                    )
                } else {
                    List(viewModel.state.objects, id: \.id) { object in
                        Button {
                            navigate(.objectDetail(object.id))
                        } label: {
                            HStack {
                                Image(systemName: iconName(for: object.type))
                                VStack(alignment: .leading) {
                                    Text(object.title)
                                    Text(object.type.rawValue)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("All Items")
            .searchable(
                text: Binding(
                    get: { viewModel.state.searchQuery },
                    set: { query in Task { await viewModel.search(query: query) } }
                )
            )
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Import", systemImage: "square.and.arrow.down") {
                        navigate(.importDocument(vaultID))
                    }
                    Button("Trash", systemImage: "trash") {
                        navigate(.trash(vaultID))
                    }
                    Button("Settings", systemImage: "gearshape") {
                        navigate(.settings(vaultID))
                    }
                    Button("Lock", systemImage: "lock") {
                        Task { await viewModel.lock(vaultID: vaultID) }
                    }
                }
            }
            .task(id: vaultID) {
                await viewModel.loadObjects()
            }
        }
    }

    private func iconName(for type: VaultObjectType) -> String {
        switch type {
        case .secureNote: "note.text"
        case .identity: "person.text.rectangle"
        case .card: "creditcard"
        case .document: "doc"
        case .photo: "photo"
        }
    }
}
