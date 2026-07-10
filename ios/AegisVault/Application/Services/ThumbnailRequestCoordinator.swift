import Foundation
import SecureVaultKit

actor ThumbnailRequestCoordinator {
    private var inFlight: [VaultObjectID: Task<VaultThumbnail, Error>] = [:]

    func thumbnail(
        for objectId: VaultObjectID,
        operation: @escaping @Sendable () async throws -> VaultThumbnail
    ) async throws -> VaultThumbnail {
        if let existing = inFlight[objectId] {
            return try await existing.value
        }

        let task = Task {
            try Task.checkCancellation()
            return try await operation()
        }
        inFlight[objectId] = task

        do {
            let thumbnail = try await task.value
            inFlight[objectId] = nil
            return thumbnail
        } catch {
            inFlight[objectId] = nil
            throw error
        }
    }

    func cancelAll() {
        for task in inFlight.values {
            task.cancel()
        }
        inFlight.removeAll(keepingCapacity: false)
    }

    func inFlightCount() -> Int {
        inFlight.count
    }
}
