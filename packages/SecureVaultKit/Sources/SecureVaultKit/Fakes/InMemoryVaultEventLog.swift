import Foundation

public actor InMemoryVaultEventLog: VaultEventLog {
    private var events: [VaultEvent] = []

    public init(events: [VaultEvent] = []) {
        self.events = events
    }

    public func append(_ event: VaultEvent) async throws {
        events.append(event)
    }

    public func listEvents(for vaultID: VaultID) async throws -> [VaultEvent] {
        events
            .filter { $0.vaultID == vaultID }
            .sorted { $0.occurredAt < $1.occurredAt }
    }
}
