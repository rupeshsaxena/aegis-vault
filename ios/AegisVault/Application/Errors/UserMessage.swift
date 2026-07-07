import Foundation

struct UserMessage: Equatable, Sendable {
    var title: String
    var message: String
    var recoverySuggestion: String?

    init(
        title: String,
        message: String,
        recoverySuggestion: String? = nil
    ) {
        self.title = title
        self.message = message
        self.recoverySuggestion = recoverySuggestion
    }
}
