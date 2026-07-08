import Foundation

struct PrivacyShieldPolicy: Equatable, Sendable {
    let protectsWhenInactive: Bool
    let protectsWhenBackgrounded: Bool
    let dismissesWhenActive: Bool

    static let standard = PrivacyShieldPolicy(
        protectsWhenInactive: true,
        protectsWhenBackgrounded: true,
        dismissesWhenActive: true
    )
}
