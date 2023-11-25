import Foundation

public enum SQLExpression: Sendable {
    case raw(String)
    case compare(_ columnName: SQLColumn.Name, _ operator: SQLOperator, _ parameter: SQLParameter)
    case `in`(field: SQLField, source: SQLInSource)
    case notIn(field: SQLField, source: SQLInSource)
}

extension SQLExpression {
    var sqlStringValue: String {
        switch self {
        case let .raw(value):
            return value
        case let .compare(columnName, op, parameter):
            return columnName.sqlStringValue + " " + op.sqlStringValue + " "
                + parameter.sqlStringValue
        case let .in(field, source):
            return field.sqlStringValue + " IN (" + source.sqlStringValue + ")"
        case let .notIn(field, source):
            return field.sqlStringValue + " NOT IN (" + source.sqlStringValue + ")"
        }
    }
}
