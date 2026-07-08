import Combine
import Foundation

@MainActor
final class PrivacyShieldController: ObservableObject {
    @Published private(set) var isShieldVisible: Bool = false

    let policy: PrivacyShieldPolicy

    init(policy: PrivacyShieldPolicy = .standard) {
        self.policy = policy
    }

    func activateForInactiveState() {
        guard policy.protectsWhenInactive else { return }
        isShieldVisible = true
    }

    func activateForBackgroundState() {
        guard policy.protectsWhenBackgrounded else { return }
        isShieldVisible = true
    }

    func dismissForActiveState() {
        guard policy.dismissesWhenActive else { return }
        isShieldVisible = false
    }
}
