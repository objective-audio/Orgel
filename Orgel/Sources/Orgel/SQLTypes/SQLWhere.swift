import Foundation

public indirect enum SQLWhere: Sendable {
    case none
    case expression(SQLExpression)
    case and([SQLWhere])
    case or([SQLWhere])
}

extension SQLWhere {
    var sqlStringValue: String {
        switch self {
        case .none:
            fatalError()
        case let .expression(expression):
            return expression.sqlStringValue
        case let .and(expressions):
            return expressions.map { "(" + $0.sqlStringValue + ")" }.joined(separator: " AND ")
        case let .or(expressions):
            return expressions.map { "(" + $0.sqlStringValue + ")" }.joined(separator: " OR ")
        }
    }

    var isEmpty: Bool {
        switch self {
        case .none:
            return true
        case let .expression(expression):
            return expression.sqlStringValue.isEmpty
        case .and(let expressions), .or(let expressions):
            if expressions.isEmpty { return true }
            return expressions.allSatisfy { $0.isEmpty }
        }
    }
}
