import Foundation

public enum SQLValue: Equatable, Sendable {
    case integer(Int64)
    case real(Double)
    case text(String)
    case blob(Data)
    case null
}

public enum SQLValueType: Sendable {
    case integer
    case real
    case text
    case blob
}

extension SQLValue {
    public var sqlStringValue: String {
        switch self {
        case let .integer(value):
            return .init(value)
        case let .real(value):
            return .init(value)
        case let .text(value):
            return "'" + value + "'"
        case .blob:
            fatalError("don't get sql from blob value")
        case .null:
            return "null"
        }
    }

    public var integerValue: Int64? {
        switch self {
        case let .integer(value):
            return value
        default:
            return nil
        }
    }

    public var realValue: Double? {
        switch self {
        case let .real(value):
            return value
        default:
            return nil
        }
    }

    public var textValue: String? {
        switch self {
        case let .text(value):
            return value
        default:
            return nil
        }
    }

    public var blobValue: Data? {
        switch self {
        case let .blob(value):
            return value
        default:
            return nil
        }
    }

    public var isNull: Bool {
        switch self {
        case .null:
            return true
        default:
            return false
        }
    }
}

extension SQLValueType {
    var sqlStringValue: String {
        switch self {
        case .integer:
            return "INTEGER"
        case .real:
            return "REAL"
        case .text:
            return "TEXT"
        case .blob:
            return "BLOB"
        }
    }
}
