import Foundation
import SecureVaultKit
import XCTest
@testable import AegisVault

final class ErrorMapperTests: XCTestCase {
    private let mapper = DefaultErrorMapper()

    func testValidationErrorMapsCorrectly() {
        let message = mapper.userMessage(for: ApplicationServiceError.validation(.missingTitle))

        XCTAssertEqual(message.title, "Missing Title")
        XCTAssertEqual(message.message, "Title is required.")
    }

    func testLockedVaultMapsCorrectly() {
        let message = mapper.userMessage(for: VaultError.locked)

        XCTAssertEqual(message.title, "Vault Locked")
        XCTAssertEqual(message.message, "Your vault is locked.")
    }

    func testNotFoundMapsCorrectly() {
        let message = mapper.userMessage(for: VaultError.objectNotFound(VaultObjectID("missing")))

        XCTAssertEqual(message.title, "Item Not Found")
        XCTAssertEqual(message.message, "This item could not be found.")
    }

    func testStorageFailureHidesInternals() {
        let message = mapper.userMessage(for: AppError.storageFailure)

        XCTAssertEqual(message.message, "Unable to save your changes.")
        XCTAssertFalse(message.message.localizedCaseInsensitiveContains("sqlite"))
        XCTAssertFalse(message.message.contains("/"))
    }

    func testUnknownErrorUsesSafeFallback() {
        let message = mapper.userMessage(
            for: MapperTestError.expected,
            fallback: UserMessage(title: "Safe", message: "Unable to complete request.")
        )

        XCTAssertEqual(message.title, "Safe")
        XCTAssertEqual(message.message, "Unable to complete request.")
    }

    func testImportErrorMapsSafely() {
        let message = mapper.userMessage(for: VaultError.unsupportedOperation("raw path /tmp/file.mov"))

        XCTAssertEqual(message.message, "This file type is not supported.")
        XCTAssertFalse(message.message.contains("/tmp"))
    }

    func testRecoveryFailureMapsSafely() {
        let message = mapper.userMessage(for: AppError.recoveryFailure)

        XCTAssertEqual(message.message, "Unable to complete the recovery request.")
    }
}

private enum MapperTestError: Error {
    case expected
}
