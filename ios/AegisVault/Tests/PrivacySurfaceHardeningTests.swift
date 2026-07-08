import XCTest
@testable import AegisVault

@MainActor
final class PrivacySurfaceHardeningTests: XCTestCase {
    func testPrivacyShieldControllerActivatesAndDismisses() {
        let controller = PrivacyShieldController()

        controller.activateForInactiveState()
        XCTAssertTrue(controller.isShieldVisible)

        controller.dismissForActiveState()
        XCTAssertFalse(controller.isShieldVisible)
    }

    func testPrivacyShieldViewDoesNotContainSensitiveLabels() throws {
        let testsURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let sourceURL = testsURL
            .deletingLastPathComponent()
            .appendingPathComponent("App/Privacy/PrivacyShieldView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8).lowercased()

        XCTAssertFalse(source.contains("note"))
        XCTAssertFalse(source.contains("card number"))
        XCTAssertFalse(source.contains("document number"))
        XCTAssertFalse(source.contains("thumbnail"))
        XCTAssertFalse(source.contains("preview"))
        XCTAssertFalse(source.contains("identity"))
    }

    func testProductionSourcesDoNotUseRawLoggingCalls() throws {
        let testsURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let appURL = testsURL.deletingLastPathComponent()
        let packageURL = appURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("packages/SecureVaultKit/Sources")
        let appSource = try ["App", "Presentation", "Application", "DesignSystem", "Infrastructure"]
            .map { try swiftSourceContents(under: appURL.appendingPathComponent($0)) }
            .joined()
        let source = appSource
            + (try swiftSourceContents(under: packageURL))

        XCTAssertFalse(source.contains("print("))
        XCTAssertFalse(source.contains("debugPrint("))
        XCTAssertFalse(source.contains("NSLog("))
        XCTAssertFalse(source.contains("Logger("))
    }

    func testScreenCaptureObserverExposesSafeState() {
        let observer = ScreenCaptureObserver(notificationCenter: NotificationCenter())

        XCTAssertTrue(
            [.unknown, .notCaptured, .captured, .unavailable].contains(observer.state)
        )
    }

    private func swiftSourceContents(under rootURL: URL) throws -> String {
        let resourceKeys: [URLResourceKey] = [.isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: resourceKeys
        ) else {
            return ""
        }

        var contents = ""
        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            let values = try fileURL.resourceValues(forKeys: Set(resourceKeys))
            guard values.isRegularFile == true else { continue }
            contents += try String(contentsOf: fileURL, encoding: .utf8)
        }
        return contents
    }
}
