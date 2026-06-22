import XCTest
@testable import SecureVaultKit

final class VaultEngineFactoryTests: XCTestCase {
    func testBootstrapEngineReportsMissingVault() async throws {
        let engine = VaultEngineFactory.makeBootstrapEngine()

        let status = try await engine.runtimeStatus()

        XCTAssertEqual(status, .missing)
    }

    func testBootstrapEngineRejectsProductOperations() async {
        let engine = VaultEngineFactory.makeBootstrapEngine()

        do {
            _ = try await engine.listObjects(filter: VaultObjectFilter())
            XCTFail("Expected the bootstrap engine to reject product operations.")
        } catch let error as VaultError {
            guard case .unsupportedOperation = error else {
                return XCTFail("Expected unsupportedOperation, received \(error).")
            }
        } catch {
            XCTFail("Expected VaultError, received \(error).")
        }
    }
}

