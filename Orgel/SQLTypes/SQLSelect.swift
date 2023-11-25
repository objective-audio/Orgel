import Foundation

public struct SQLSelect: Sendable {
    public enum Order: Sendable {
        case ascending
        case descending

        public var sqlStringValue: String {
            switch self {
            case .ascending:
                return "ASC"
            case .descending:
                return "DESC"
            }
        }
    }

    public struct ColumnOrder: Sendable {
        public let name: SQLColumn.Name
        public let order: Order

        public init(name: SQLColumn.Name, order: Order = .ascending) {
            self.name = name
            self.order = order
        }

        var sqlStringValue: String { name.sqlStringValue + " " + order.sqlStringValue }
    }

    public struct Range: Sendable {
        public let location: Int
        public let length: Int

        public static var empty: Range { .init(location: 0, length: 0) }

        public var isEmpty: Bool { length == 0 }

        var sqlStringValue: String { "\(location), \(length)" }

        public init(location: Int, length: Int) {
            self.location = location
            self.length = length
        }
    }

    public var table: SQLTable
    public var field: SQLField
    public var `where`: SQLWhere
    public var parameters: [SQLParameter.Name: SQLValue]
    public var columnOrders: [ColumnOrder]
    public var limitRange: Range
    public var groupBy: [SQLColumn.Name]
    public var distinct: Bool

    public init(
        table: SQLTable, field: SQLField = .wildcard, where: SQLWhere = .none,
        parameters: [SQLParameter.Name: SQLValue] = [:],
        columnOrders: [ColumnOrder] = [], limitRange: Range = .empty,
        groupBy: [SQLColumn.Name] = [],
        distinct: Bool = false
    ) {
        self.table = table
        self.field = field
        self.where = `where`
        self.parameters = parameters
        self.columnOrders = columnOrders
        self.limitRange = limitRange
        self.groupBy = groupBy
        self.distinct = distinct
    }
}

extension SQLSelect {
    var sqlStringValue: String {
        var result = "SELECT "

        if distinct {
            result += "DISTINCT "
        }

        result += field.sqlStringValue + " FROM " + table.sqlStringValue

        if !`where`.isEmpty {
            result += " WHERE \(`where`.sqlStringValue)"
        }

        if !columnOrders.isEmpty {
            result += " ORDER BY " + columnOrders.sqlStringValue
        }

        if !limitRange.isEmpty {
            result += " LIMIT " + limitRange.sqlStringValue
        }

        if !groupBy.isEmpty {
            result += " GROUP BY \(groupBy.map(\.sqlStringValue).joined(separator: ", "))"
        }

        return result
    }
}

extension Sequence where Element == SQLSelect.ColumnOrder {
    var sqlStringValue: String {
        map { $0.sqlStringValue }.joined(separator: ", ")
    }
}
