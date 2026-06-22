import Foundation
import SecureVaultKit
import XCTest
@testable import AegisVault

@MainActor
final class SettingsSecurityViewModelTests: XCTestCase {
    func testSettingsInitialStateIsIdle() {
        let viewModel = SettingsViewModel(
            getSecurityStatusUseCase: SecurityStatusUseCase(result: .success(makeStatus()))
        )

        XCTAssertEqual(viewModel.state, .idle)
    }

    func testSettingsLoadSuccess() async {
        let viewModel = SettingsViewModel(
            getSecurityStatusUseCase: SecurityStatusUseCase(result: .success(makeStatus()))
        )

        await viewModel.loadSettings()

        guard case .loaded(let summary) = viewModel.state else {
            return XCTFail("Expected loaded settings.")
        }
        XCTAssertEqual(summary.lockState, .unlocked)
        XCTAssertEqual(summary.trustedDevicesCount, 1)
    }

    func testSettingsLoadFailure() async {
        let viewModel = SettingsViewModel(
            getSecurityStatusUseCase: SecurityStatusUseCase(result: .failure(SettingsTestError.expected))
        )

        await viewModel.loadSettings()

        XCTAssertEqual(viewModel.state, .failed("Unable to load settings."))
    }

    func testSecurityCenterLoadSuccess() async {
        let viewModel = makeSecurityCenterViewModel()

        await viewModel.loadSecurityStatus()

        guard case .loaded(let status) = viewModel.state else {
            return XCTFail("Expected loaded security status.")
        }
        XCTAssertEqual(status.autoLockPolicy, .fiveMinutes)
        XCTAssertEqual(status.trustedDevices.count, 1)
    }

    func testManualLockCallsLockVaultUseCase() async {
        let lockUseCase = SecurityLockUseCase()
        let viewModel = makeSecurityCenterViewModel(lockUseCase: lockUseCase)
        let vaultID = VaultID("vault")

        await viewModel.lock(vaultID: vaultID)

        let receivedIDs = await lockUseCase.receivedIDs()
        XCTAssertEqual(receivedIDs, [vaultID])
        XCTAssertEqual(viewModel.lockedVaultID, vaultID)
    }

    func testUpdateAutoLockCallsUseCase() async {
        let updateUseCase = AutoLockUpdateUseCase(result: .success(()))
        let viewModel = makeSecurityCenterViewModel(updateUseCase: updateUseCase)
        await viewModel.loadSecurityStatus()

        await viewModel.updateAutoLockPolicy(.fifteenMinutes)

        let policies = await updateUseCase.receivedPolicies()
        XCTAssertEqual(policies, [.fifteenMinutes])
        guard case .loaded(let status) = viewModel.state else {
            return XCTFail("Expected loaded security status.")
        }
        XCTAssertEqual(status.autoLockPolicy, .fifteenMinutes)
    }

    func testRecoveryIncompleteWarningIsShown() async {
        let viewModel = makeSecurityCenterViewModel()

        await viewModel.loadSecurityStatus()

        guard case .loaded(let status) = viewModel.state else {
            return XCTFail("Expected loaded security status.")
        }
        XCTAssertTrue(status.showsRecoveryWarning)
    }

    func testTrustedDevicesCountIsDisplayedWhenAvailable() async {
        let viewModel = SettingsViewModel(
            getSecurityStatusUseCase: SecurityStatusUseCase(result: .success(makeStatus()))
        )

        await viewModel.loadSettings()

        guard case .loaded(let summary) = viewModel.state else {
            return XCTFail("Expected loaded settings.")
        }
        XCTAssertEqual(summary.trustedDevicesCount, 1)
    }

    func testViewModelsDoNotDependOnInfrastructureOrExposeSessionKeys() throws {
        let testsURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let settingsDirectory = testsURL
            .deletingLastPathComponent()
            .appendingPathComponent("Presentation/Settings")
        let settingsSource = try String(
            contentsOf: settingsDirectory.appendingPathComponent("SettingsViewModel.swift"),
            encoding: .utf8
        )
        let securitySource = try String(
            contentsOf: settingsDirectory.appendingPathComponent("SecurityCenterViewModel.swift"),
            encoding: .utf8
        )
        let combined = settingsSource + securitySource

        XCTAssertFalse(combined.contains("StorageEngine"))
        XCTAssertFalse(combined.contains("CryptoEngine"))
        XCTAssertFalse(combined.contains("BlobStore"))
        XCTAssertFalse(combined.contains("keyReference"))
        XCTAssertFalse(combined.contains("KeyMaterial"))
    }

    private func makeSecurityCenterViewModel(
        updateUseCase: AutoLockUpdateUseCase = AutoLockUpdateUseCase(result: .success(())),
        lockUseCase: SecurityLockUseCase = SecurityLockUseCase()
    ) -> SecurityCenterViewModel {
        SecurityCenterViewModel(
            getSecurityStatusUseCase: SecurityStatusUseCase(result: .success(makeStatus())),
            updateAutoLockPolicyUseCase: updateUseCase,
            lockVaultUseCase: lockUseCase
        )
    }

    private func makeStatus() -> VaultSecurityStatus {
        VaultSecurityStatus(
            vaultId: VaultID("vault"),
            lockState: .unlocked,
            autoLockPolicy: .fiveMinutes,
            biometricStatus: .notConfigured,
            passkeyStatus: .notConfigured,
            recoveryStatus: .incomplete,
            trustedDevices: [
                TrustedDeviceSummary(
                    deviceId: DeviceID("device"),
                    name: "This iPhone",
                    platform: "iOS",
                    createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                    isCurrentDevice: true
                )
            ]
        )
    }
}

private actor SecurityStatusUseCase: GetSecurityStatusUsing {
    let result: Result<VaultSecurityStatus, Error>

    init(result: Result<VaultSecurityStatus, Error>) {
        self.result = result
    }

    func execute() async throws -> VaultSecurityStatus {
        try result.get()
    }
}

private actor AutoLockUpdateUseCase: UpdateAutoLockPolicyUsing {
    let result: Result<Void, Error>
    private var policies: [AutoLockPolicy] = []

    init(result: Result<Void, Error>) {
        self.result = result
    }

    func execute(policy: AutoLockPolicy) async throws {
        policies.append(policy)
        try result.get()
    }

    func receivedPolicies() -> [AutoLockPolicy] {
        policies
    }
}

private actor SecurityLockUseCase: LockVaultUsing {
    private var vaultIDs: [VaultID] = []

    func execute(vaultID: VaultID) async {
        vaultIDs.append(vaultID)
    }

    func receivedIDs() -> [VaultID] {
        vaultIDs
    }
}

private enum SettingsTestError: Error {
    case expected
}
