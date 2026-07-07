import Foundation

protocol ErrorMapper: Sendable {
    func appError(from error: Error) -> AppError
    func userMessage(for error: Error) -> UserMessage
    func userMessage(for error: Error, fallback: UserMessage) -> UserMessage
}
