import Foundation

public enum SQLInSource: Sendable {
    case select(SQLSelect)
    case values([SQLValue])
    case ids(Set<StableId>)
}

extension SQLInSource {
    var sqlStringValue: String {
        switch self {
        case let .select(select):
            return select.sqlStringValue
        case let .values(values):
            return values.map { $0.sqlStringValue }.joined(separator: ", ")
        case let .ids(ids):
            return ids.map { String($0.rawValue) }.sorted().joined(separator: ", ")
        }
    }
}
