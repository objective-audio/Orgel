import Foundation

public enum SQLUpdate: Sendable {
    case raw(String)
    case createTable(SQLTable, columns: [SQLColumn])
    case alterTable(SQLTable, column: SQLColumn)
    case dropTable(SQLTable)
    case createIndex(SQLIndex, table: SQLTable, columnNames: [SQLColumn.Name])
    case dropIndex(SQLIndex)
    case insert(table: SQLTable, columnNames: [SQLColumn.Name] = [])
    case update(table: SQLTable, columnNames: [SQLColumn.Name], where: SQLWhere = .none)
    case delete(table: SQLTable, where: SQLWhere = .none)
    case beginTransation
    case commitTransaction
    case rollbackTransaction
    case vacuum
}

extension SQLUpdate {
    var sqlStringValue: String {
        switch self {
        case let .raw(value):
            return value
        case let .createTable(table, columns):
            let joinedColumns = columns.map(\.sqlStringValue).joined(separator: ", ")
            return "CREATE TABLE IF NOT EXISTS " + table.sqlStringValue + " (" + joinedColumns
                + ");"
        case let .alterTable(table, column):
            return "ALTER TABLE " + table.sqlStringValue + " ADD COLUMN " + column.sqlStringValue
                + ";"
        case let .dropTable(table):
            return "DROP TABLE IF EXISTS " + table.sqlStringValue + ";"
        case let .createIndex(index, table, columnNames):
            let joinedNames = columnNames.map(\.sqlStringValue).joined(separator: ", ")
            return
                "CREATE INDEX IF NOT EXISTS " + index.sqlStringValue + " ON " + table.sqlStringValue
                + "("
                + joinedNames + ");"
        case let .dropIndex(index):
            return "DROP INDEX IF EXISTS " + index.sqlStringValue + ";"
        case let .insert(table, columnNames):
            var result = "INSERT INTO " + table.sqlStringValue

            if !columnNames.isEmpty {
                let joinedNames = columnNames.map(\.sqlStringValue).joined(separator: ", ")
                let joinedValues = columnNames.map { ":" + $0.sqlStringValue }.joined(
                    separator: ", ")
                result += "(" + joinedNames + ") VALUES(" + joinedValues + ");"
            } else {
                result += " DEFAULT VALUES;"
            }

            return result
        case let .update(table, columnNames, expressions):
            var result =
                "UPDATE \(table.sqlStringValue) SET "
                + columnNames.map {
                    SQLExpression.compare(
                        $0, .equal, .name($0.defaultParameterName)
                    ).sqlStringValue
                }
                .joined(
                    separator: ", ")

            if !expressions.isEmpty {
                result += " WHERE " + expressions.sqlStringValue
            }

            return result + ";"
        case let .delete(table, expressions):
            var result = "DELETE FROM \(table.sqlStringValue)"

            if !expressions.isEmpty {
                result += " WHERE " + expressions.sqlStringValue
            }

            return result + ";"
        case .beginTransation:
            return "BEGIN EXCLUSIVE TRANSACTION"
        case .commitTransaction:
            return "COMMIT TRANSACTION"
        case .rollbackTransaction:
            return "ROLLBACK TRANSACTION"
        case .vacuum:
            return "VACUUM;"
        }
    }
}
