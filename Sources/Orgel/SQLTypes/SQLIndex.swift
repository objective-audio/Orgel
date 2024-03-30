import Foundation

public struct SQLIndex: Hashable, Sendable {
    let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

extension SQLIndex {
    var sqlStringValue: String { rawValue }
}
