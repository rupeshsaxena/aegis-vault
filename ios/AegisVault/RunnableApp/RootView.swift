import SwiftUI

struct RootView: View {
    let container: AppContainer

    var body: some View {
        Text("AegisVault")
            .font(.largeTitle.bold())
            .accessibilityIdentifier("aegisVaultTitle")
    }
}

