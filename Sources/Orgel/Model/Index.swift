import Foundation

public struct Index: Sendable {
    public typealias Name = SQLIndex

    public let name: Name
    public let entity: Entity.Name
    public let attributes: [Attribute.Name]

    public init(name: Name, entity: Entity.Name, attributes: [Attribute.Name]) throws {
        enum InitError: Error {
            case nameIsEmpty
            case entityIsEmpty
            case attributesAreEmpty
            case attributeIsEmpty
        }

        self.name = name
        self.entity = entity
        self.attributes = attributes

        if name.sqlStringValue.isEmpty {
            throw InitError.nameIsEmpty
        }

        if entity.rawValue.isEmpty {
            throw InitError.entityIsEmpty
        }

        if attributes.isEmpty {
            throw InitError.attributesAreEmpty
        }

        for attribute in attributes where attribute.rawValue.isEmpty {
            throw InitError.attributeIsEmpty
        }
    }

    public var sqlForCreate: SQLUpdate {
        .createIndex(
            name, table: entity.table,
            columnNames: attributes.map(\.columnName))
    }
}
