import Foundation

public struct Relation: Sendable {
    public struct Name: Hashable, Sendable {
        let rawValue: String

        public init(_ rawValue: String) {
            self.rawValue = rawValue
        }
    }

    public let name: Name
    public let source: Entity.Name
    public let target: Entity.Name
    public let many: Bool

    public var table: SQLTable { .init("rel_\(source.rawValue)_\(name.rawValue)") }

    public init(name: Name, source: Entity.Name, target: Entity.Name, many: Bool = false) throws {
        enum InitError: Error {
            case nameIsEmpty
            case sourceIsEmpty
            case targetIsEmpty
        }

        self.name = name
        self.source = source
        self.target = target
        self.many = many

        if name.rawValue.isEmpty {
            throw InitError.nameIsEmpty
        }

        if source.rawValue.isEmpty {
            throw InitError.sourceIsEmpty
        }

        if target.rawValue.isEmpty {
            throw InitError.targetIsEmpty
        }
    }

    public var sqlForCreate: SQLUpdate {
        let pkIdDef = Attribute.pkId.column
        let sourcePkIdSql = try! Attribute(
            name: .sourcePkId, value: .integer(.allowNull(nil))
        )
        .column
        let sourceObjectIdDef = try! Attribute(
            name: .sourceObjectId, value: .integer(.allowNull(nil))
        )
        .column
        let targetObjectIdDef = try! Attribute(
            name: .targetObjectId, value: .integer(.allowNull(nil))
        )
        .column
        let saveIdDef = try! Attribute(
            name: .saveId, value: .integer(.allowNull(nil))
        )
        .column

        return .createTable(
            table,
            columns: [
                pkIdDef, sourcePkIdSql, sourceObjectIdDef,
                targetObjectIdDef, saveIdDef,
            ])
    }

    public var sqlForInsert: SQLUpdate {
        .insert(
            table: table,
            columnNames: [
                .sourcePkId, .sourceObjectId, .targetObjectId,
                .saveId,
            ])
    }
}

extension Relation.Name: CustomStringConvertible {
    public var description: String {
        rawValue
    }
}
