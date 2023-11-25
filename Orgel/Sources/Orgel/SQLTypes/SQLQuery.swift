import Foundation

public enum SQLQuery: Sendable {
    case raw(String)
    case select(SQLSelect)
}

extension SQLQuery {
    var sqlStringValue: String {
        switch self {
        case let .raw(value):
            return value
        case let .select(select):
            return select.sqlStringValue
        }
    }
}
