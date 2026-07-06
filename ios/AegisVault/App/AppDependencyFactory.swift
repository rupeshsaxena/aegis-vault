import Foundation
import SecureVaultKit

struct AppDependencyFactory {
    let environment: AppEnvironment
    let fileManager: FileManager
    private let applicationSupportOverrideURL: URL?

    init(
        environment: AppEnvironment,
        fileManager: FileManager = .default,
        applicationSupportURL: URL? = nil
    ) {
        self.environment = environment
        self.fileManager = fileManager
        self.applicationSupportOverrideURL = applicationSupportURL
    }

    func makeVaultEngine() throws -> any VaultEngine {
        try VaultEngineFactory.makePersistentLocalEngine(
            storageURL: persistentStorageURL()
        )
    }

    func persistentStorageURL() throws -> URL {
        let applicationSupportURL: URL
        if let applicationSupportOverrideURL {
            applicationSupportURL = applicationSupportOverrideURL
        } else {
            applicationSupportURL = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        }
        let storageURL = applicationSupportURL
            .appendingPathComponent(environment.storageDirectoryName, isDirectory: true)
        try fileManager.createDirectory(at: storageURL, withIntermediateDirectories: true)
        return storageURL
    }
}
