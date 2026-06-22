import Foundation

struct ThumbnailViewData: Equatable, Sendable {
    let data: Data
    let contentType: String
}

enum ThumbnailViewState: Equatable, Sendable {
    case idle
    case loading
    case loaded(ThumbnailViewData)
    case placeholder
}
