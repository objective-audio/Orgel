import Foundation

public struct TemporaryId: Hashable, Sendable, Codable {
    let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

extension TemporaryId: Comparable {
    public static func < (lhs: TemporaryId, rhs: TemporaryId) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

extension TemporaryId: CustomStringConvertible {
    public var description: String { rawValue }
}
