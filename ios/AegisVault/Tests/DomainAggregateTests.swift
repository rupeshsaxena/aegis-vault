import SecureVaultKit
import XCTest
@testable import AegisVault

final class DomainAggregateTests: XCTestCase {
    func testSecureNoteAggregateValidNoteCreatesDraft() throws {
        let aggregate = SecureNoteAggregate(
            data: SecureNoteEditorViewData(title: "  Note  ", content: "Body", tags: ["personal"])
        )

        let draft = try aggregate.toVaultObjectDraft()

        XCTAssertEqual(draft.type, .secureNote)
        XCTAssertEqual(draft.metadata.title, "Note")
        XCTAssertEqual(draft.payload.notes, "Body")
    }

    func testSecureNoteAggregateEmptyTitleFails() {
        let aggregate = SecureNoteAggregate(data: SecureNoteEditorViewData(title: " "))

        XCTAssertThrowsError(try aggregate.toVaultObjectDraft()) { error in
            XCTAssertEqual(error as? ValidationError, .missingTitle)
        }
    }

    func testIdentityAggregateValidIdentityCreatesDraft() throws {
        var data = IdentityEditorViewData()
        data.title = "Passport"
        data.identityType = .passport
        data.fullName = "A User"
        data.documentNumber = "P123"

        let draft = try IdentityAggregate(data: data).toVaultObjectDraft()

        XCTAssertEqual(draft.type, .identity)
        XCTAssertEqual(draft.metadata.category, IdentityDocumentType.passport.rawValue)
    }

    func testIdentityAggregateEmptyTitleFails() {
        var data = IdentityEditorViewData()
        data.title = " "
        data.documentNumber = "P123"

        XCTAssertThrowsError(try IdentityAggregate(data: data).toVaultObjectDraft()) { error in
            XCTAssertEqual(error as? ValidationError, .missingTitle)
        }
    }

    func testIdentityAggregateRequiredDocumentNumberFailsWhenMissing() {
        var data = IdentityEditorViewData()
        data.title = "Passport"
        data.identityType = .passport
        data.documentNumber = " "

        XCTAssertThrowsError(try IdentityAggregate(data: data).toVaultObjectDraft()) { error in
            XCTAssertEqual(error as? ValidationError, .missingRequiredField("documentNumber"))
        }
    }

    func testIdentityAggregateDocumentNumberMapsToSecureText() throws {
        var data = IdentityEditorViewData()
        data.title = "Passport"
        data.documentNumber = "P123"

        let draft = try IdentityAggregate(data: data).toVaultObjectDraft()

        guard case .secureText("P123") = draft.payload.fields["documentNumber"] else {
            return XCTFail("Expected documentNumber to map to secureText.")
        }
    }

    func testIdentityAggregateMapsToIdentityType() throws {
        var data = IdentityEditorViewData()
        data.title = "PAN"
        data.identityType = .pan
        data.documentNumber = "ABCDE1234F"

        XCTAssertEqual(try IdentityAggregate(data: data).toVaultObjectDraft().type, .identity)
    }

    func testCardAggregateValidCardCreatesDraft() throws {
        var data = CardEditorViewData()
        data.title = "Travel Card"
        data.cardType = .creditCard
        data.cardNumber = "4111111111111111"

        let draft = try CardAggregate(data: data).toVaultObjectDraft()

        XCTAssertEqual(draft.type, .card)
        XCTAssertEqual(draft.metadata.category, CardType.creditCard.rawValue)
    }

    func testCardAggregateEmptyTitleFails() {
        var data = CardEditorViewData()
        data.title = " "
        data.cardNumber = "4111"

        XCTAssertThrowsError(try CardAggregate(data: data).toVaultObjectDraft()) { error in
            XCTAssertEqual(error as? ValidationError, .missingTitle)
        }
    }

    func testCardAggregateRequiredCardNumberFailsWhenMissing() {
        var data = CardEditorViewData()
        data.title = "Travel Card"
        data.cardType = .creditCard
        data.cardNumber = " "

        XCTAssertThrowsError(try CardAggregate(data: data).toVaultObjectDraft()) { error in
            XCTAssertEqual(error as? ValidationError, .missingRequiredField("cardNumber"))
        }
    }

    func testCardAggregateCardNumberMapsToSecureText() throws {
        var data = CardEditorViewData()
        data.title = "Travel Card"
        data.cardNumber = "4111"

        let draft = try CardAggregate(data: data).toVaultObjectDraft()

        guard case .secureText("4111") = draft.payload.fields["cardNumber"] else {
            return XCTFail("Expected cardNumber to map to secureText.")
        }
    }

    func testCardAggregateMapsToCardType() throws {
        var data = CardEditorViewData()
        data.title = "Membership"
        data.cardType = .membershipCard

        XCTAssertEqual(try CardAggregate(data: data).toVaultObjectDraft().type, .card)
    }

    func testDocumentAggregateValidDocumentMapsToDocumentType() throws {
        let aggregate = DocumentAggregate(
            fileInfo: DocumentImportFileInfo(
                fileName: "passport.pdf",
                contentType: "application/pdf",
                originalSizeBytes: 12
            )
        )

        XCTAssertEqual(try aggregate.toVaultObjectDraft().type, .document)
    }

    func testDocumentAggregateMissingFilenameFails() {
        let aggregate = DocumentAggregate(
            fileInfo: DocumentImportFileInfo(fileName: " ", contentType: "application/pdf", originalSizeBytes: 12)
        )

        XCTAssertThrowsError(try aggregate.toVaultObjectDraft()) { error in
            XCTAssertEqual(error as? ValidationError, .missingRequiredField("filename"))
        }
    }

    func testDocumentAggregateMissingContentTypeFails() {
        let aggregate = DocumentAggregate(
            fileInfo: DocumentImportFileInfo(fileName: "passport.pdf", contentType: " ", originalSizeBytes: 12)
        )

        XCTAssertThrowsError(try aggregate.toVaultObjectDraft()) { error in
            XCTAssertEqual(error as? ValidationError, .missingRequiredField("contentType"))
        }
    }
}
