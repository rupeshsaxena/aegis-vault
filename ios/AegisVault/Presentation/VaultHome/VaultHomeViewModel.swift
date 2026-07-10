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
    private let errorMapper: any ErrorMapper
    private let thumbnailRequestCoordinator: ThumbnailRequestCoordinator
    private var loadTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var thumbnailTasks: [VaultObjectID: Task<Void, Never>] = [:]
    private var refreshRequestID = UUID()

    init(
        listVaultObjectsUseCase: any ListVaultObjectsUsing,
        searchVaultUseCase: any SearchVaultUsing,
        lockVaultUseCase: any LockVaultUsing,
        loadThumbnailUseCase: any LoadThumbnailUsing,
        errorMapper: any ErrorMapper = DefaultErrorMapper(),
        thumbnailRequestCoordinator: ThumbnailRequestCoordinator = ThumbnailRequestCoordinator()
    ) {
        self.listVaultObjectsUseCase = listVaultObjectsUseCase
        self.searchVaultUseCase = searchVaultUseCase
        self.lockVaultUseCase = lockVaultUseCase
        self.loadThumbnailUseCase = loadThumbnailUseCase
        self.errorMapper = errorMapper
        self.thumbnailRequestCoordinator = thumbnailRequestCoordinator
    }

    deinit {
        loadTask?.cancel()
        searchTask?.cancel()
        for task in thumbnailTasks.values {
            task.cancel()
        }
    }

    func loadObjects() async {
        searchTask?.cancel()
        loadTask?.cancel()
        let requestID = beginRefreshRequest()
        state = .loading
        let filter = VaultObjectFilter(types: selectedFilter.objectTypes)
        let task = Task { [listVaultObjectsUseCase] in
            do {
                let summaries = try await listVaultObjectsUseCase.execute(filter: filter)
                try Task.checkCancellation()
                await MainActor.run {
                    guard self.refreshRequestID == requestID else { return }
                    self.present(summaries)
                }
            } catch is CancellationError {
            } catch {
                await MainActor.run {
                    guard self.refreshRequestID == requestID else { return }
                    self.state = .error(self.message(for: error).message)
                }
            }
        }
        loadTask = task
        await task.value
    }

    func search(query: String) async {
        loadTask?.cancel()
        searchTask?.cancel()
        searchQuery = query
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            await loadObjects()
            return
        }

        let requestID = beginRefreshRequest()
        let filter = VaultObjectFilter(types: selectedFilter.objectTypes)
        let task = Task { [searchVaultUseCase] in
            do {
                try await Task.sleep(for: .milliseconds(300))
                try Task.checkCancellation()
                let summaries = try await searchVaultUseCase.execute(query: query, filter: filter)
                try Task.checkCancellation()
                await MainActor.run {
                    guard self.refreshRequestID == requestID,
                          self.searchQuery == query else { return }
                    self.present(summaries)
                }
            } catch is CancellationError {
            } catch {
                await MainActor.run {
                    guard self.refreshRequestID == requestID,
                          self.searchQuery == query else { return }
                    self.state = .error(self.message(for: error).message)
                }
            }
        }
        searchTask = task
        await task.value
    }

    func selectFilter(_ filter: VaultObjectTypeFilter) async {
        selectedFilter = filter
        if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            await loadObjects()
        } else {
            await search(query: searchQuery)
        }
    }

    func clearFilter() async {
        await selectFilter(.all)
    }

    func selectObject(id: VaultObjectID) {
        route = .objectDetail(id)
    }

    func addItem(to vaultID: VaultID) {
        addIdentity(to: vaultID)
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
        if let task = thumbnailTasks[objectId] {
            await task.value
            return
        }
        guard thumbnailStates[objectId] == nil else { return }
        thumbnailStates[objectId] = .loading
        let task = Task { [loadThumbnailUseCase, thumbnailRequestCoordinator] in
            do {
                let thumbnail = try await thumbnailRequestCoordinator.thumbnail(for: objectId) {
                    try await loadThumbnailUseCase.execute(objectId: objectId)
                }
                try Task.checkCancellation()
                await MainActor.run {
                    self.thumbnailStates[objectId] = .loaded(
                        ThumbnailViewData(data: thumbnail.data, contentType: thumbnail.contentType)
                    )
                    self.thumbnailTasks[objectId] = nil
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.thumbnailTasks[objectId] = nil
                }
            } catch {
                await MainActor.run {
                    self.thumbnailStates[objectId] = .placeholder
                    self.thumbnailTasks[objectId] = nil
                }
            }
        }
        thumbnailTasks[objectId] = task
        await task.value
    }

    func lock(vaultID: VaultID) async {
        cancelPresentationWork()
        await thumbnailRequestCoordinator.cancelAll()
        await lockVaultUseCase.execute(vaultID: vaultID)
        searchQuery = ""
        selectedFilter = .all
        thumbnailStates.removeAll(keepingCapacity: false)
        lockedVaultID = vaultID
        state = .loading
    }

    private func beginRefreshRequest() -> UUID {
        let requestID = UUID()
        refreshRequestID = requestID
        return requestID
    }

    private func cancelPresentationWork() {
        loadTask?.cancel()
        searchTask?.cancel()
        for task in thumbnailTasks.values {
            task.cancel()
        }
        thumbnailTasks.removeAll(keepingCapacity: false)
    }

    private func message(for error: Error) -> UserMessage {
        errorMapper.userMessage(
            for: error,
            fallback: UserMessage(
                title: "Unable to Load Vault",
                message: searchQuery.isEmpty ? "Unable to load vault items." : "Unable to search the vault."
            )
        )
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
