import Foundation

public enum SQLOperator: Sendable {
    case raw(String)
    case equal
    case notEqual
    case greaterThan
    case greaterThanOrEqual
    case lessThan
    case lessThanOrEqual
    case like
    case notLike
    case `in`
}

extension SQLOperator {
    var sqlStringValue: String {
        switch self {
        case let .raw(value):
            return value
        case .equal:
            return "="
        case .notEqual:
            return "!="
        case .greaterThan:
            return ">"
        case .greaterThanOrEqual:
            return ">="
        case .lessThan:
            return "<"
        case .lessThanOrEqual:
            return "<="
        case .like:
            return "LIKE"
        case .notLike:
            return "NOT LIKE"
        case .in:
            return "IN"
        }
    }
}
