import Foundation

public struct VersionVector: Codable, Hashable, Sendable {
    public private(set) var versions: [String: Int]

    public init(_ versions: [String: Int] = [:]) {
        self.versions = versions
    }

    public subscript(deviceId: DeviceID) -> Int {
        versions[deviceId.rawValue, default: 0]
    }

    public mutating func increment(for deviceId: DeviceID) {
        versions[deviceId.rawValue, default: 0] += 1
    }

    public func incremented(for deviceId: DeviceID) -> VersionVector {
        var copy = self
        copy.increment(for: deviceId)
        return copy
    }

    public func dominates(_ other: VersionVector) -> Bool {
        var hasStrictlyGreaterVersion = false
        for device in Set(versions.keys).union(other.versions.keys) {
            let local = versions[device, default: 0]
            let remote = other.versions[device, default: 0]
            if local < remote {
                return false
            }
            if local > remote {
                hasStrictlyGreaterVersion = true
            }
        }
        return hasStrictlyGreaterVersion || versions == other.versions
    }

    public func isConcurrent(with other: VersionVector) -> Bool {
        !dominates(other) && !other.dominates(self)
    }
}

