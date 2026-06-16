public enum VaultSessionActorState: Equatable, Sendable {
    case locked
    case unlocked(VaultSession)
}

public actor VaultSessionActor {
    private var activeSession: VaultSession?

    public init() {}

    public func unlock(session: VaultSession) {
        var unlockedSession = session
        unlockedSession.lockState = .unlocked
        activeSession = unlockedSession
    }

    public func lock() {
        activeSession = nil
    }

    public func requireUnlocked() throws -> VaultSession {
        guard let activeSession, activeSession.lockState == .unlocked else {
            throw VaultError.locked
        }
        return activeSession
    }

    public func currentState() -> VaultSessionActorState {
        guard let activeSession, activeSession.lockState == .unlocked else {
            return .locked
        }
        return .unlocked(activeSession)
    }
}
