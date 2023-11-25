import Foundation

public struct Model: Sendable {
    public struct EntityArgs {
        public let name: Entity.Name
        public let attributes: [Entity.AttributeArgs]
        public let relations: [Entity.RelationArgs]

        public init(
            name: Entity.Name, attributes: [Entity.AttributeArgs], relations: [Entity.RelationArgs]
        ) {
            self.name = name
            self.attributes = attributes
            self.relations = relations
        }
    }

    public struct IndexArgs {
        public let name: Index.Name
        public let entity: Entity.Name
        public let attributes: [Attribute.Name]

        public init(name: Index.Name, entity: Entity.Name, attributes: [Attribute.Name]) {
            self.name = name
            self.entity = entity
            self.attributes = attributes
        }
    }

    public let version: Version
    public let entities: [Entity.Name: Entity]
    public let indices: [Index.Name: Index]

    public init(version: Version, entities: [EntityArgs], indices: [IndexArgs]) throws {
        self.version = version

        let entityInvRelNames = makeInverseRelationNames(entities: entities)

        self.entities = try entities.reduce(
            into: .init(),
            { partialResult, entityArgs in
                partialResult[entityArgs.name] = try .init(
                    name: entityArgs.name, attributes: entityArgs.attributes,
                    relations: entityArgs.relations,
                    inverseRelationNames: entityInvRelNames[entityArgs.name] ?? [:])
            })

        self.indices = try indices.reduce(
            into: .init(),
            { partialResult, indexArgs in
                partialResult[indexArgs.name] = try .init(
                    name: indexArgs.name, entity: indexArgs.entity, attributes: indexArgs.attributes
                )
            })
    }
}

private func makeInverseRelationNames(entities: [Model.EntityArgs]) -> [Entity.Name: [Entity.Name:
    Set<
        Relation.Name
    >]]
{
    var result: [Entity.Name: [Entity.Name: Set<Relation.Name>]] = [:]

    for entity in entities {
        for relation in entity.relations {
            if result[relation.target] == nil {
                result[relation.target] = .init()
            }

            if result[relation.target]![entity.name] == nil {
                result[relation.target]![entity.name] = .init()
            }

            result[relation.target]![entity.name]!.insert(relation.name)
        }
    }

    return result
}
