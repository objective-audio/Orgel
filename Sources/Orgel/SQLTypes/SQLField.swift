import Foundation

public enum SQLField: Equatable, Sendable {
    case wildcard
    case column(SQLColumn.Name)
    case columns([SQLColumn.Name])
    case not(SQLColumn.Name)
    case max(SQLColumn.Name)
}

extension SQLField {
    public var sqlStringValue: String {
        switch self {
        case .wildcard:
            return "*"
        case let .column(value):
            return value.sqlStringValue
        case let .columns(values):
            return values.map(\.sqlStringValue).joined(separator: ", ")
        case let .not(columnName):
            return "NOT " + columnName.sqlStringValue
        case let .max(columnName):
            return "MAX(" + columnName.sqlStringValue + ")"
        }
    }
}
