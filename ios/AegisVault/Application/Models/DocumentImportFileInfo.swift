import Foundation

struct DocumentImportFileInfo: Equatable, Sendable {
    let fileName: String
    let contentType: String
    let originalSizeBytes: Int64
}
