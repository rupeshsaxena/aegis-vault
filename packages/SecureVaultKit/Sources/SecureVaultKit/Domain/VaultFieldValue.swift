import Foundation

public enum VaultFieldValue: Equatable, Codable, Sendable {
    case text(String)
    case secureText(String)
    case number(Double)
    case boolean(Bool)
    case date(Date)
    case url(String)
    case email(String)
    case phone(String)
}
