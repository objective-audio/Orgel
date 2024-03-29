import Foundation

public struct StableId: Hashable, Sendable, Codable {
    let rawValue: Int64

    public init(_ rawValue: Int64) {
        self.rawValue = rawValue
    }
}

extension StableId {
    var sqlValue: SQLValue {
        .integer(rawValue)
    }
}

extension StableId: Comparable {
    public static func < (lhs: StableId, rhs: StableId) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

extension StableId: CustomStringConvertible {
    public var description: String { String(rawValue) }
}
