import Foundation

public enum ObjectAction: String, Sendable {
    case insert
    case update
    case remove
}

extension ObjectAction {
    var sqlValue: SQLValue {
        .text(rawValue)
    }
}
