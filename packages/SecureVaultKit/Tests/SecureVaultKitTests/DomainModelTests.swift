import XCTest
@testable import SecureVaultKit

final class DomainModelTests: XCTestCase {
    func testVaultItemPayloadReportsKind() {
        let note = VaultItemPayload.secureNote(SecureNote(body: "Launch codes stay offline."))
        let identity = VaultItemPayload.identity(IdentityRecord(fullName: "Ada Lovelace"))
        let card = VaultItemPayload.paymentCard(PaymentCard(cardholderName: "Ada Lovelace", last4: "1234"))

        XCTAssertEqual(note.kind, .secureNote)
        XCTAssertEqual(identity.kind, .identity)
        XCTAssertEqual(card.kind, .paymentCard)
    }

    func testTrashPolicyDefaultsToThirtyDays() {
        XCTAssertEqual(TrashPolicy().retentionDays, 30)
        XCTAssertEqual(TrashPolicy.defaultRetentionDays, 30)
    }

    func testBlobBackedModelsKeepEncryptedAssetReferences() {
        let blob = BlobDescriptor(id: "blob-1", contentType: "image/jpeg", byteCount: 42, encryptedDigest: "digest")
        let thumbnail = PreviewDescriptor(blobID: "thumb-1", pixelWidth: 128, pixelHeight: 128)
        let photo = VaultPhoto(blob: blob, thumbnail: thumbnail)

        XCTAssertEqual(photo.blob.id, "blob-1")
        XCTAssertEqual(photo.thumbnail?.blobID, "thumb-1")
    }
}
