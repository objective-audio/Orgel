import Foundation

public struct FetchOption: Sendable {
    public private(set) var selects: [SQLTable: SQLSelect]

    public init() {
        selects = [:]
    }

    public init(selects: [SQLSelect]) {
        var result: [SQLTable: SQLSelect] = [:]

        for select in selects {
            guard result[select.table] == nil else {
                assertionFailure()
                continue
            }
            result[select.table] = select
        }

        self.selects = result
    }

    public init(stableIds: [Entity.Name: Set<StableId>]) {
        var selects: [SQLTable: SQLSelect] = [:]

        for (entityName, ids) in stableIds {
            selects[entityName.table] = .init(
                table: entityName.table,
                where: .expression(.in(field: .column(.objectId), source: .ids(ids)))
            )
        }

        self.selects = selects
    }

    public mutating func addSelect(_ select: SQLSelect) throws {
        enum AddError: Error {
            case duplicateTable
        }

        guard selects[select.table] == nil else {
            throw AddError.duplicateTable
        }

        selects[select.table] = select
    }
}
