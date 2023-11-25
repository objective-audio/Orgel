import Foundation

extension SQLWhere {
    static func last(
        table: SQLTable, where expressions: SQLWhere, lastSaveId: Int64?, includeRemoved: Bool
    ) -> SQLWhere {
        var components: [SQLWhere] = []

        if let lastSaveId {
            components.append(
                .expression(.compare(.saveId, .lessThanOrEqual, .value(.integer(lastSaveId))))
            )
        }

        if !expressions.isEmpty {
            components.append(expressions)
        }

        let select = SQLSelect(
            table: table, field: .max(.rowid),
            where: .and(components), groupBy: [.objectId]
        )

        let inExprs = SQLWhere.expression(
            .in(field: .column(.rowid), source: .select(select)))

        if includeRemoved {
            return inExprs
        } else {
            return .and([
                inExprs,
                .expression(.compare(.action, .notEqual, .value(.removeAction))),
            ])
        }
    }
}
