import Foundation

extension SQLValue {
    static var insertAction: SQLValue {
        .text("insert")
    }

    static var updateAction: SQLValue {
        .text("update")
    }

    static var removeAction: SQLValue {
        .text("remove")
    }
}

extension [SQLValue] {
    init(_ objectIds: [StableId]) {
        self = objectIds.map(\.sqlValue)
    }
}
