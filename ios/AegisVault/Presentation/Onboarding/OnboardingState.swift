import Foundation
import SecureVaultKit

enum OnboardingStep: Int, CaseIterable, Equatable, Sendable {
    case welcome
    case securityPrinciples
    case createVault
    case recoveryPackage
    case biometricSetup
    case completion

    var previous: OnboardingStep? {
        OnboardingStep(rawValue: rawValue - 1)
    }

    var next: OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }
}

struct OnboardingState: Equatable {
    enum Phase: Equatable {
        case idle
        case creating
        case created
        case failed
    }

    var step: OnboardingStep = .welcome
    var vaultName = ""
    var phase: Phase = .idle
    var createdVaultID: VaultID?
    var completedVaultID: VaultID?
    var recoveryWarningAcknowledged = false
    var biometricSetupSkipped = false
    var errorMessage: String?

    var canCreateVault: Bool {
        step == .createVault
            && createdVaultID == nil
            && !vaultName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && phase != .creating
    }

    var canGoBack: Bool {
        step != .welcome
            && phase != .creating
            && !(step == .recoveryPackage && createdVaultID != nil)
    }

    var canContinue: Bool {
        switch step {
        case .welcome, .securityPrinciples, .biometricSetup:
            true
        case .createVault:
            createdVaultID != nil
        case .recoveryPackage:
            recoveryWarningAcknowledged
        case .completion:
            createdVaultID != nil && recoveryWarningAcknowledged
        }
    }
}
