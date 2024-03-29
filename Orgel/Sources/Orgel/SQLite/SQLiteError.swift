import Foundation
import SQLite3

public struct SQLiteError: Error {
    public enum Kind: Sendable {
        case closed
        case invalidQueryCount
        case prepareFailed
        case stepFailed
        case finalizeFailed
        case sqlite
    }

    public let kind: Kind
    public let result: SQLiteResult
    public let message: String

    public init(
        kind: Kind, result: SQLiteResult = .init(rawValue: SQLITE_OK),
        message: String = ""
    ) {
        self.kind = kind
        self.result = result
        self.message = message
    }
}
