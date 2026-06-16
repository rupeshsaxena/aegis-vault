import XCTest
@testable import SecureVaultKit

final class SecureVaultKitTests: XCTestCase {
    func testPackageLoads() {
        XCTAssertNotNil(SecureVaultKit.self)
    }
}
