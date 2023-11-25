import Foundation

public enum SQLParameter: Sendable {
    public struct Name: Hashable, Sendable {
        let rawValue: String

        public init(_ rawValue: String) {
            self.rawValue = rawValue
        }
    }

    case name(SQLParameter.Name)
    case value(SQLValue)
}

extension SQLParameter.Name {
    var sqlStringValue: String {
        ":" + rawValue
    }
}

extension SQLParameter {
    var sqlStringValue: String {
        switch self {
        case let .name(name):
            return name.sqlStringValue
        case let .value(value):
            return value.sqlStringValue
        }
    }
}
