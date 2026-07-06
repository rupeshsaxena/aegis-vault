import Foundation

struct AppEnvironment: Sendable {
    enum Runtime: Sendable {
        case simulator
        case debug
        case release
        case preview
    }

    let runtime: Runtime
    let storageDirectoryName: String

    init(
        runtime: Runtime,
        storageDirectoryName: String = "AegisVault"
    ) {
        self.runtime = runtime
        self.storageDirectoryName = storageDirectoryName
    }

    static func current() -> AppEnvironment {
        #if DEBUG
        #if targetEnvironment(simulator)
        AppEnvironment(runtime: .simulator)
        #else
        AppEnvironment(runtime: .debug)
        #endif
        #else
        AppEnvironment(runtime: .release)
        #endif
    }

    static let preview = AppEnvironment(runtime: .preview)
}
