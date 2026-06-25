import SecureVaultKit
import SwiftUI

@main
@MainActor
struct AegisVaultApp: App {
    private let container: AppContainer

    init() {
        self.container = AppContainer(engineFactory: { VaultEngineFactory.makeSimulatorEngine() })
    }

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
        }
    }
}
