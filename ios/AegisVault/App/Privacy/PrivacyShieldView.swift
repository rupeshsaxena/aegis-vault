import SwiftUI

struct PrivacyShieldView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text("AegisVault")
                    .font(.title2.weight(.semibold))

                Text("Protected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("privacy-shield")
    }
}

private struct PrivacyShieldModifier: ViewModifier {
    @ObservedObject var controller: PrivacyShieldController

    func body(content: Content) -> some View {
        content.overlay {
            if controller.isShieldVisible {
                PrivacyShieldView()
                    .transition(.opacity)
            }
        }
    }
}

extension View {
    func privacyShielded(by controller: PrivacyShieldController) -> some View {
        modifier(PrivacyShieldModifier(controller: controller))
    }
}
