import Foundation

public actor VaultSessionActor {
    private var activeSession: VaultSession?
    private var state: VaultSessionState = .locked
    private var autoLockPolicy: AutoLockPolicy
    private let cleanupHandler: (any SessionCleanupHandler)?

    public init(
        autoLockPolicy: AutoLockPolicy = .fiveMinutes,
        cleanupHandler: (any SessionCleanupHandler)? = nil
    ) {
        self.autoLockPolicy = autoLockPolicy
        self.cleanupHandler = cleanupHandler
    }

    public func unlock(session: VaultSession) {
        state = .unlocking
        var unlockedSession = session
        unlockedSession.expiresAt = expirationDate(from: unlockedSession.lastAccessedAt)
        activeSession = unlockedSession
        state = .unlocked
    }

    public func lock() async {
        await performLock()
    }

    public func requireUnlocked() async throws -> VaultSession {
        guard state == .unlocked, var session = activeSession else {
            throw VaultError.locked
        }

        let now = Date()
        if isExpired(session: session, now: now) {
            await performLock()
            throw VaultError.locked
        }

        session.lastAccessedAt = now
        session.expiresAt = expirationDate(from: now)
        activeSession = session
        return session
    }

    public func currentState() -> VaultSessionState {
        state
    }

    public func updateLastAccessed() async throws {
        guard state == .unlocked, var session = activeSession else {
            throw VaultError.locked
        }
        let now = Date()
        if isExpired(session: session, now: now) {
            await performLock()
            throw VaultError.locked
        }
        session.lastAccessedAt = now
        session.expiresAt = expirationDate(from: now)
        activeSession = session
    }

    public func isExpired(now: Date) -> Bool {
        guard state == .unlocked, let session = activeSession else {
            return false
        }
        return isExpired(session: session, now: now)
    }

    @discardableResult
    public func lockIfExpired(now: Date) async -> Bool {
        guard isExpired(now: now) else {
            return false
        }
        await performLock()
        return true
    }

    public func configureAutoLockPolicy(_ policy: AutoLockPolicy) {
        autoLockPolicy = policy
        guard var session = activeSession else {
            return
        }
        session.expiresAt = expirationDate(from: session.lastAccessedAt)
        activeSession = session
    }

    public func currentAutoLockPolicy() -> AutoLockPolicy {
        autoLockPolicy
    }

    private func expirationDate(from date: Date) -> Date? {
        autoLockPolicy.timeout.map { date.addingTimeInterval($0) }
    }

    private func isExpired(session: VaultSession, now: Date) -> Bool {
        guard let expiresAt = session.expiresAt else {
            return false
        }
        return now >= expiresAt
    }

    private func performLock() async {
        state = .locking
        await cleanupHandler?.clearSearchIndex()
        await cleanupHandler?.clearPreviewCache()
        await cleanupHandler?.clearThumbnailCache()
        await cleanupHandler?.clearDecryptedObjectCache()
        activeSession = nil
        state = .locked
    }
}
