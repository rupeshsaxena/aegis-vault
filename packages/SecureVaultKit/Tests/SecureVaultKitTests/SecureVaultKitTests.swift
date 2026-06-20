import XCTest
@testable import SecureVaultKit

final class SecureVaultKitTests: XCTestCase {
    func testIDUniqueness() {
        XCTAssertNotEqual(VaultID(), VaultID())
        XCTAssertNotEqual(VaultObjectID(), VaultObjectID())
        XCTAssertNotEqual(DeviceID(), DeviceID())
        XCTAssertNotEqual(BlobID(), BlobID())
    }

    func testVaultObjectDraftInitialization() {
        let metadata = VaultMetadata(title: "Passport", tags: ["travel"])
        let payload = VaultPayload(fields: ["number": .secureText("123456789")])
        let draft = VaultObjectDraft(type: .document, metadata: metadata, payload: payload)

        XCTAssertEqual(draft.type, .document)
        XCTAssertEqual(draft.metadata.title, "Passport")
        XCTAssertEqual(draft.metadata.tags, ["travel"])
        XCTAssertEqual(draft.payload.fields["number"], .secureText("123456789"))
    }

    func testVaultMetadataInitialization() {
        let createdAt = Date(timeIntervalSince1970: 10)
        let updatedAt = Date(timeIntervalSince1970: 20)
        let metadata = VaultMetadata(
            title: "Secure note",
            subtitle: "Personal",
            tags: ["private", "offline"],
            isFavorite: true,
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        XCTAssertEqual(metadata.title, "Secure note")
        XCTAssertEqual(metadata.subtitle, "Personal")
        XCTAssertEqual(metadata.tags, ["private", "offline"])
        XCTAssertTrue(metadata.isFavorite)
        XCTAssertEqual(metadata.createdAt, createdAt)
        XCTAssertEqual(metadata.updatedAt, updatedAt)
        XCTAssertNil(metadata.deletedAt)
    }

    func testVaultObjectTypeCases() {
        XCTAssertEqual(
            Set(VaultObjectType.allCases),
            [.secureNote, .identity, .card, .document, .photo]
        )
    }

    func testVaultErrorEquality() {
        let vaultID = VaultID("vault-1")
        let objectID = VaultObjectID("object-1")

        XCTAssertEqual(VaultError.vaultNotFound(vaultID), .vaultNotFound(vaultID))
        XCTAssertEqual(VaultError.objectNotFound(objectID), .objectNotFound(objectID))
        XCTAssertEqual(VaultError.locked, .locked)
        XCTAssertEqual(VaultError.authenticationFailed, .authenticationFailed)
        XCTAssertEqual(VaultError.invalidInput("title required"), .invalidInput("title required"))
        XCTAssertNotEqual(VaultError.invalidInput("a"), .invalidInput("b"))
    }
}
