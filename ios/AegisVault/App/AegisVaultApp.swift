import SecureVaultKit
import SwiftUI

struct AegisVaultApp: View {
    private let container: AppContainer

    @MainActor
    init(engineFactory: @escaping @Sendable () -> any VaultEngine) {
        self.container = AppContainer(engineFactory: engineFactory)
    }

    var body: some View {
        RootView(container: container)
    }
}
