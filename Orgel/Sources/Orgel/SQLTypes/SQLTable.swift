import Foundation

public struct SQLTable: Hashable, Sendable {
    let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

extension SQLTable {
    var sqlStringValue: String { rawValue }
}

extension SQLTable {
    static let sqliteMaster: SQLTable = .init("sqlite_master")
}
