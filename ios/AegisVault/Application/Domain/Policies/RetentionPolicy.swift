import Foundation

struct RetentionPolicy {
    let retentionInterval: TimeInterval

    init(retentionInterval: TimeInterval = 30 * 24 * 60 * 60) {
        self.retentionInterval = retentionInterval
    }

    func purgeDate(for deletedAt: Date) -> Date {
        deletedAt.addingTimeInterval(retentionInterval)
    }

    func isExpired(deletedAt: Date, now: Date = Date()) -> Bool {
        purgeDate(for: deletedAt) <= now
    }
}
