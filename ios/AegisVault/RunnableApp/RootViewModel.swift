import Observation

@MainActor
@Observable
final class RootViewModel {
    private(set) var route: RootRoute?
    private(set) var errorMessage: String?

    @ObservationIgnored private let resolveRootRouteUseCase: any ResolveRootRouteUsing

    init(resolveRootRouteUseCase: any ResolveRootRouteUsing) {
        self.resolveRootRouteUseCase = resolveRootRouteUseCase
    }

    func determineInitialRoute() async {
        guard route == nil else { return }
        do {
            route = try await resolveRootRouteUseCase.execute()
            errorMessage = nil
        } catch {
            errorMessage = "Unable to open AegisVault."
        }
    }
}

