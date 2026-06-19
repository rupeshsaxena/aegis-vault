import Foundation

public enum KeyState: String, Codable, Sendable {
    case active
    case retired
    case compromised
    case pendingRotation
}

public struct KeyVersion: Equatable, Codable, Sendable {
    public var keyId: KeyIdentifier
    public var versionNumber: Int
    public var createdAt: Date
    public var retiredAt: Date?
    public var state: KeyState

    public init(
        keyId: KeyIdentifier,
        versionNumber: Int,
        createdAt: Date = Date(),
        retiredAt: Date? = nil,
        state: KeyState = .active
    ) {
        self.keyId = keyId
        self.versionNumber = versionNumber
        self.createdAt = createdAt
        self.retiredAt = retiredAt
        self.state = state
    }
}

public struct KeyRotationPolicy: Equatable, Codable, Sendable {
    public var rotationInterval: TimeInterval?
    public var allowManualRotation: Bool
    public var maxActiveKeyAge: TimeInterval?

    public init(
        rotationInterval: TimeInterval? = nil,
        allowManualRotation: Bool = true,
        maxActiveKeyAge: TimeInterval? = nil
    ) {
        self.rotationInterval = rotationInterval
        self.allowManualRotation = allowManualRotation
        self.maxActiveKeyAge = maxActiveKeyAge
    }
}

public struct KeyRotationPlan: Equatable, Codable, Sendable {
    public var oldKeyId: KeyIdentifier
    public var newKeyId: KeyIdentifier
    public var affectedObjectIds: [VaultObjectID]
    public var affectedBlobIds: [BlobID]
    public var createdAt: Date

    public init(
        oldKeyId: KeyIdentifier,
        newKeyId: KeyIdentifier,
        affectedObjectIds: [VaultObjectID] = [],
        affectedBlobIds: [BlobID] = [],
        createdAt: Date = Date()
    ) {
        self.oldKeyId = oldKeyId
        self.newKeyId = newKeyId
        self.affectedObjectIds = affectedObjectIds
        self.affectedBlobIds = affectedBlobIds
        self.createdAt = createdAt
    }
}

public enum KeyRotationStatus: String, Codable, Sendable {
    case planned
}

public struct KeyRotationResult: Equatable, Codable, Sendable {
    public var plan: KeyRotationPlan
    public var status: KeyRotationStatus

    public init(plan: KeyRotationPlan, status: KeyRotationStatus = .planned) {
        self.plan = plan
        self.status = status
    }
}
