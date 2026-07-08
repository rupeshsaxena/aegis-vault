import Foundation

enum ScreenCaptureState: Equatable, Sendable {
    case unknown
    case notCaptured
    case captured
    case unavailable
}
