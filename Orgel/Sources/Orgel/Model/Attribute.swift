import Foundation

public struct Attribute: Sendable {
    public struct Name: Hashable, Sendable {
        public let rawValue: String

        public init(_ rawValue: String) {
            self.rawValue = rawValue
        }
    }

    public enum Value: Equatable, Sendable {
        public enum RawValue<T: Equatable & Sendable>: Equatable, Sendable {
            case notNull(T)
            case allowNull(T?)
        }

        case integer(RawValue<Int64>)
        case real(RawValue<Double>)
        case text(RawValue<String>)
        case blob(RawValue<Data>)

        var type: SQLValueType {
            switch self {
            case .integer:
                return .integer
            case .real:
                return .real
            case .text:
                return .text
            case .blob:
                return .blob
            }
        }
    }

    public let name: Name
    public let value: Value
    public let primary: Bool
    public let unique: Bool

    public var defaultValue: SQLValue {
        switch value {
        case let .integer(value):
            switch value {
            case let .notNull(rawValue):
                return .integer(rawValue)
            case let .allowNull(rawValue):
                if let rawValue {
                    return .integer(rawValue)
                }
            }
        case let .real(value):
            switch value {
            case let .notNull(rawValue):
                return .real(rawValue)
            case let .allowNull(rawValue):
                if let rawValue {
                    return .real(rawValue)
                }
            }
        case let .text(value):
            switch value {
            case let .notNull(rawValue):
                return .text(rawValue)
            case let .allowNull(rawValue):
                if let rawValue {
                    return .text(rawValue)
                }
            }
        case let .blob(value):
            switch value {
            case let .notNull(rawValue):
                return .blob(rawValue)
            case let .allowNull(rawValue):
                if let rawValue {
                    return .blob(rawValue)
                }
            }
        }
        return .null
    }

    public var notNull: Bool {
        switch value {
        case .integer(.notNull), .real(.notNull), .text(.notNull), .blob(.notNull):
            return true
        default:
            return false
        }
    }

    public init(
        name: Name, value: Value,
        primary: Bool = false, unique: Bool = false
    ) throws {
        enum InitError: Error {
            case nameIsEmpty
        }

        self.name = name
        self.value = value
        self.primary = primary
        self.unique = unique

        if name.rawValue.isEmpty {
            throw InitError.nameIsEmpty
        }
    }

    var column: SQLColumn {
        .init(
            name: name.columnName, valueType: value.type, primary: primary, unique: unique,
            notNull: notNull,
            defaultValue: defaultValue)
    }
}

extension Attribute {
    static var pkId: Attribute {
        return try! .init(
            name: .pkId, value: .integer(.allowNull(nil)), primary: true)
    }

    static var objectId: Attribute {
        return try! .init(
            name: .objectId, value: .integer(.notNull(0)))
    }

    static var saveId: Attribute {
        return try! .init(
            name: .saveId, value: .integer(.notNull(0)))
    }

    static var action: Attribute {
        return try! .init(
            name: .action, value: .text(.notNull("insert")))
    }
}

extension Attribute.Name {
    static let objectId: Self = .init(SQLColumn.Name.objectId.sqlStringValue)
    static let action: Self = .init(SQLColumn.Name.action.sqlStringValue)
    static let saveId: Self = .init(SQLColumn.Name.saveId.sqlStringValue)
    static let pkId: Self = .init(SQLColumn.Name.pkId.sqlStringValue)
    static let sourcePkId: Self = .init(SQLColumn.Name.sourcePkId.sqlStringValue)
    static let sourceObjectId: Self = .init(SQLColumn.Name.sourceObjectId.sqlStringValue)
    static let targetObjectId: Self = .init(SQLColumn.Name.targetObjectId.sqlStringValue)

    public var columnName: SQLColumn.Name { .init(rawValue) }
}

extension Attribute.Name: CustomStringConvertible {
    public var description: String {
        rawValue
    }
}
