import Foundation

public struct SQLColumn: Sendable {
    public struct Name: Hashable, Sendable {
        let rawValue: String

        public init(_ rawValue: String) {
            self.rawValue = rawValue
        }
    }

    let name: SQLColumn.Name
    let valueType: SQLValueType
    let primary: Bool
    let unique: Bool
    let notNull: Bool
    let defaultValue: SQLValue

    public init(
        name: SQLColumn.Name, valueType: SQLValueType, primary: Bool = false, unique: Bool = false,
        notNull: Bool = false, defaultValue: SQLValue = .null
    ) {
        self.name = name
        self.valueType = valueType
        self.primary = primary
        self.unique = unique
        self.notNull = notNull
        self.defaultValue = defaultValue
    }
}

extension SQLColumn {
    var sqlStringValue: String {
        var result = name.sqlStringValue + " " + valueType.sqlStringValue

        if primary {
            result += " PRIMARY KEY AUTOINCREMENT"
        }

        if unique {
            result += " UNIQUE"
        }

        if notNull {
            result += " NOT NULL"
        }

        if !defaultValue.isNull {
            result += " DEFAULT \(defaultValue.sqlStringValue)"
        }

        return result
    }
}

extension SQLColumn.Name {
    var sqlStringValue: String { rawValue }

    var defaultParameterName: SQLParameter.Name {
        .init(sqlStringValue)
    }
}

extension SQLColumn.Name {
    enum System {
        static let name: SQLColumn.Name = .init("name")
    }
}
