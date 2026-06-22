import Foundation
import SecureVaultKit

enum TrashState: Equatable {
    case idle
    case loading
    case loaded([TrashItemViewData])
    case empty
    case failed(String)
}

struct TrashItemViewData: Equatable, Identifiable {
    static let retentionDays = 30

    let id: VaultObjectID
    let title: String
    let type: VaultObjectType
    let deletedAt: Date
    let purgeAfter: Date?
    let remainingDays: Int?

    init(summary: VaultObjectSummary, now: Date = Date()) {
        id = summary.id
        title = summary.title
        type = summary.type
        deletedAt = summary.deletedAt ?? summary.updatedAt
        purgeAfter = Calendar.current.date(
            byAdding: .day,
            value: Self.retentionDays,
            to: deletedAt
        )
        if let purgeAfter {
            remainingDays = max(
                0,
                Calendar.current.dateComponents(
                    [.day],
                    from: Calendar.current.startOfDay(for: now),
                    to: Calendar.current.startOfDay(for: purgeAfter)
                ).day ?? 0
            )
        } else {
            remainingDays = nil
        }
    }
}
