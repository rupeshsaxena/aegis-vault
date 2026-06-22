import Observation
import SecureVaultKit
import SwiftUI

// MARK: - View Model

@MainActor
@Observable
final class VaultHomeViewModel {
    private(set) var objects: [VaultObjectSummary] = []
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?

    var isEmpty: Bool { !isLoading && objects.isEmpty && errorMessage == nil }

    @ObservationIgnored private let listVaultObjectsUseCase: any ListVaultObjectsUsing

    init(listVaultObjectsUseCase: any ListVaultObjectsUsing) {
        self.listVaultObjectsUseCase = listVaultObjectsUseCase
    }

    func loadObjects() async {
        isLoading = true
        errorMessage = nil
        do {
            objects = try await listVaultObjectsUseCase.execute(filter: VaultObjectFilter())
        } catch {
            errorMessage = "Failed to load vault: \(error.localizedDescription)"
        }
        isLoading = false
    }
}

// MARK: - View

struct VaultHomeView: View {
    let vaultID: VaultID
    var viewModel: VaultHomeViewModel

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                } else if let error = viewModel.errorMessage {
                    ContentUnavailableView(
                        "Unable to Load Vault",
                        systemImage: "exclamationmark.lock",
                        description: Text(error)
                    )
                } else if viewModel.isEmpty {
                    emptyState
                } else {
                    objectList
                }
            }
            .navigationTitle("AegisVault")
            .navigationBarTitleDisplayMode(.large)
        }
        .task {
            await viewModel.loadObjects()
        }
        .accessibilityIdentifier("vaultHomeTitle")
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Secrets Yet",
            systemImage: "lock.open",
            description: Text("Add your first secret to get started.")
        )
        .accessibilityIdentifier("vaultEmptyState")
    }

    private var objectList: some View {
        List(viewModel.objects, id: \.id) { object in
            Text(object.title)
        }
        .accessibilityIdentifier("vaultObjectList")
    }
}
