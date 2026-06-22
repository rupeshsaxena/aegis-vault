import Combine
import Foundation
import SecureVaultKit

@MainActor
final class VaultHomeViewModel: ObservableObject {
    @Published private(set) var state: VaultHomeState = .loading
    @Published private(set) var searchQuery = ""
    @Published private(set) var selectedFilter: VaultObjectTypeFilter = .all
    @Published private(set) var route: AppRoute?
    @Published private(set) var lockedVaultID: VaultID?
    @Published private(set) var thumbnailStates: [VaultObjectID: ThumbnailViewState] = [:]

    private let listVaultObjectsUseCase: any ListVaultObjectsUsing
    private let searchVaultUseCase: any SearchVaultUsing
    private let lockVaultUseCase: any LockVaultUsing
    private let loadThumbnailUseCase: any LoadThumbnailUsing

    init(
        listVaultObjectsUseCase: any ListVaultObjectsUsing,
        searchVaultUseCase: any SearchVaultUsing,
        lockVaultUseCase: any LockVaultUsing,
        loadThumbnailUseCase: any LoadThumbnailUsing
    ) {
        self.listVaultObjectsUseCase = listVaultObjectsUseCase
        self.searchVaultUseCase = searchVaultUseCase
        self.lockVaultUseCase = lockVaultUseCase
        self.loadThumbnailUseCase = loadThumbnailUseCase
    }

    func loadObjects() async {
        state = .loading
        await refreshResults()
    }

    func search(query: String) async {
        searchQuery = query
        await refreshResults()
    }

    func selectFilter(_ filter: VaultObjectTypeFilter) async {
        selectedFilter = filter
        await refreshResults()
    }

    func clearFilter() async {
        await selectFilter(.all)
    }

    func selectObject(id: VaultObjectID) {
        route = .objectDetail(id)
    }

    func addItem(to vaultID: VaultID) {
        addSecureNote(to: vaultID)
    }

    func addSecureNote(to vaultID: VaultID) {
        route = .secureNoteEditor(.create(vaultID))
    }

    func addIdentity(to vaultID: VaultID) {
        route = .identityEditor(.create(vaultID))
    }

    func addCard(to vaultID: VaultID) {
        route = .cardEditor(.create(vaultID))
    }

    func importDocument(into vaultID: VaultID) {
        route = .importDocument(vaultID)
    }

    func showTrash(for vaultID: VaultID) {
        route = .trash(vaultID)
    }

    func showSettings(for vaultID: VaultID) {
        route = .settings(vaultID)
    }

    func clearRoute() {
        route = nil
    }

    func loadThumbnail(for objectId: VaultObjectID) async {
        guard thumbnailStates[objectId] == nil else { return }
        thumbnailStates[objectId] = .loading
        do {
            let thumbnail = try await loadThumbnailUseCase.execute(objectId: objectId)
            thumbnailStates[objectId] = .loaded(
                ThumbnailViewData(data: thumbnail.data, contentType: thumbnail.contentType)
            )
        } catch {
            thumbnailStates[objectId] = .placeholder
        }
    }

    func lock(vaultID: VaultID) async {
        await lockVaultUseCase.execute(vaultID: vaultID)
        searchQuery = ""
        selectedFilter = .all
        thumbnailStates.removeAll(keepingCapacity: false)
        lockedVaultID = vaultID
        state = .loading
    }

    private func refreshResults() async {
        let filter = VaultObjectFilter(types: selectedFilter.objectTypes)

        do {
            let summaries: [VaultObjectSummary]
            if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                summaries = try await listVaultObjectsUseCase.execute(filter: filter)
            } else {
                summaries = try await searchVaultUseCase.execute(query: searchQuery, filter: filter)
            }
            present(summaries)
        } catch VaultError.locked {
            state = .error("Unlock your vault to search.")
        } catch {
            state = .error(searchQuery.isEmpty ? "Unable to load vault items." : "Unable to search the vault.")
        }
    }

    private func present(_ summaries: [VaultObjectSummary]) {
        let visibleIDs = Set(summaries.map(\.id))
        thumbnailStates = thumbnailStates.filter { visibleIDs.contains($0.key) }
        guard !summaries.isEmpty else {
            state = .empty(emptyState)
            return
        }
        state = .loaded(summaries.map(VaultObjectSummaryViewData.init(summary:)))
    }

    private var emptyState: VaultHomeEmptyState {
        if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return VaultHomeEmptyState(
                title: "No results",
                suggestion: "Try another search or filter."
            )
        }

        switch selectedFilter {
        case .notes:
            return VaultHomeEmptyState(title: "No notes yet", suggestion: "Create your first note")
        case .documents:
            return VaultHomeEmptyState(title: "No documents yet", suggestion: "Import your first document")
        default:
            return VaultHomeEmptyState(title: "No items yet", suggestion: "Add your first vault item")
        }
    }
}
