import Foundation
import SecureVaultKit
import XCTest
@testable import AegisVault

@MainActor
final class RecoverySettingsViewModelTests: XCTestCase {
    func testInitialStateIsIdle() {
        XCTAssertEqual(makeViewModel().state, .idle)
    }

    func testLoadStatusSuccess() async {
        let exportedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let viewModel = makeViewModel(
            statusResult: .success(RecoveryStatus(isConfigured: false, lastExportedAt: exportedAt))
        )

        await viewModel.loadStatus()

        guard case .loaded(let status) = viewModel.state else {
            return XCTFail("Expected loaded recovery status.")
        }
        XCTAssertFalse(status.isRecoveryConfigured)
        XCTAssertEqual(status.lastExportedAt, exportedAt)
        XCTAssertTrue(status.warningMessage.contains("recovery package and recovery secret"))
        XCTAssertTrue(status.warningMessage.contains("vault may be unrecoverable"))
    }

    func testLoadStatusFailure() async {
        let viewModel = makeViewModel(statusResult: .failure(RecoverySettingsTestError.expected))

        await viewModel.loadStatus()

        XCTAssertEqual(viewModel.state, .failed("Unable to load recovery status."))
    }

    func testExportRequiresAcknowledgment() async {
        let exportUseCase = RecoveryExportUseCase(result: .success(makeExport()))
        let viewModel = makeViewModel(exportUseCase: exportUseCase)

        await viewModel.exportPackage()

        XCTAssertEqual(
            viewModel.state,
            .failed("Acknowledge the recovery responsibility before exporting.")
        )
        let callCount = await exportUseCase.callCount()
        XCTAssertEqual(callCount, 0)
    }

    func testExportSuccessState() async {
        let export = makeExport()
        let exportUseCase = RecoveryExportUseCase(result: .success(export))
        let viewModel = makeViewModel(exportUseCase: exportUseCase)
        viewModel.setAcknowledgedRisk(true)

        await viewModel.exportPackage()

        XCTAssertEqual(viewModel.state, .exported(RecoveryExportViewData(export: export)))
        let acknowledgments = await exportUseCase.receivedAcknowledgments()
        XCTAssertEqual(acknowledgments, [true])
    }

    func testExportFailureState() async {
        let viewModel = makeViewModel(
            exportUseCase: RecoveryExportUseCase(result: .failure(RecoverySettingsTestError.expected))
        )
        viewModel.setAcknowledgedRisk(true)

        await viewModel.exportPackage()

        XCTAssertEqual(viewModel.state, .failed("Unable to export recovery package."))
    }

    func testLockedErrorMappingIsUserSafe() async {
        let viewModel = makeViewModel(
            exportUseCase: RecoveryExportUseCase(result: .failure(VaultError.locked))
        )
        viewModel.setAcknowledgedRisk(true)

        await viewModel.exportPackage()

        XCTAssertEqual(viewModel.state, .failed("Your vault is locked."))
    }

    func testViewModelDoesNotDependOnInternalRecoveryOrInfrastructureServices() throws {
        let testsURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let sourceURL = testsURL
            .deletingLastPathComponent()
            .appendingPathComponent("Presentation/Settings/RecoverySettingsViewModel.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertFalse(source.contains("RecoveryPackageService"))
        XCTAssertFalse(source.contains("CryptoEngine"))
        XCTAssertFalse(source.contains("StorageEngine"))
        XCTAssertFalse(source.contains("BlobStore"))
        XCTAssertFalse(source.contains("KeyMaterial"))
        XCTAssertFalse(source.contains("keyReference"))
    }

    private func makeViewModel(
        statusResult: Result<RecoveryStatus, Error> = .success(RecoveryStatus(isConfigured: false)),
        exportUseCase: RecoveryExportUseCase? = nil
    ) -> RecoverySettingsViewModel {
        RecoverySettingsViewModel(
            getRecoveryStatusUseCase: RecoveryStatusUseCase(result: statusResult),
            exportRecoveryPackageUseCase: exportUseCase
                ?? RecoveryExportUseCase(result: .success(makeExport()))
        )
    }

    private func makeExport() -> RecoveryPackageExport {
        RecoveryPackageExport(
            fileName: "AegisVault-Recovery-Package.json",
            exportedAt: Date(timeIntervalSince1970: 1_700_000_000),
            formatVersion: 1,
            temporaryFileURL: URL(fileURLWithPath: "/tmp/recovery.json")
        )
    }
}

private actor RecoveryStatusUseCase: GetRecoveryStatusUsing {
    let result: Result<RecoveryStatus, Error>

    init(result: Result<RecoveryStatus, Error>) {
        self.result = result
    }

    func execute() async throws -> RecoveryStatus {
        try result.get()
    }
}

private actor RecoveryExportUseCase: ExportRecoveryPackageUsing {
    let result: Result<RecoveryPackageExport, Error>
    private var acknowledgments: [Bool] = []

    init(result: Result<RecoveryPackageExport, Error>) {
        self.result = result
    }

    func execute(acknowledgingRisk: Bool) async throws -> RecoveryPackageExport {
        acknowledgments.append(acknowledgingRisk)
        return try result.get()
    }

    func receivedAcknowledgments() -> [Bool] {
        acknowledgments
    }

    func callCount() -> Int {
        acknowledgments.count
    }
}

private enum RecoverySettingsTestError: Error {
    case expected
}
