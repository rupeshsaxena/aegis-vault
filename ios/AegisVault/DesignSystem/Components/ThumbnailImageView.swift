import SwiftUI
import UIKit

struct ThumbnailImageView: View {
    let state: ThumbnailViewState
    let fallbackSystemImage: String
    var size: CGFloat = 40

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView()
            case .loaded(let thumbnail):
                if let image = UIImage(data: thumbnail.data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    fallback
                }
            case .idle, .placeholder:
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .accessibilityHidden(true)
    }

    private var fallback: some View {
        Image(systemName: fallbackSystemImage)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.quaternary)
    }
}
