import SecureVaultKit
import SwiftUI

@main
@MainActor
struct AegisVaultApp: App {
    private let container: AppContainer

    init() {
        do {
            self.container = try AppContainer.makeDefault()
        } catch {
            preconditionFailure("Unable to initialize AegisVault dependencies: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
        }
    }
}
