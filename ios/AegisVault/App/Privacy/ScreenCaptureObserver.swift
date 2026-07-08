import Combine
import Foundation
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class ScreenCaptureObserver: ObservableObject {
    @Published private(set) var state: ScreenCaptureState

    private var notificationObserver: NSObjectProtocol?
    private let notificationCenter: NotificationCenter

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
        #if canImport(UIKit)
        state = UIScreen.main.isCaptured ? .captured : .notCaptured
        notificationObserver = notificationCenter.addObserver(
            forName: UIScreen.capturedDidChangeNotification,
            object: UIScreen.main,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
        #else
        state = .unavailable
        #endif
    }

    deinit {
        if let notificationObserver {
            notificationCenter.removeObserver(notificationObserver)
        }
    }

    func refresh() {
        #if canImport(UIKit)
        state = UIScreen.main.isCaptured ? .captured : .notCaptured
        #else
        state = .unavailable
        #endif
    }
}
