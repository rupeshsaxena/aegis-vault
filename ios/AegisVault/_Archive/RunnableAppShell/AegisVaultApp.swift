import SwiftUI

@main
@MainActor
struct AegisVaultApp: App {
    private let container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
        }
    }
}
