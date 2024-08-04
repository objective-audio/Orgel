import Foundation

public struct Entity: Sendable {
    public struct Name: Hashable, Sendable {
        let rawValue: String

        public init(_ rawValue: String) {
            self.rawValue = rawValue
        }

        init(table: SQLTable) {
            rawValue = table.sqlStringValue
        }
    }

    public struct AttributeArgs {
        public let name: Attribute.Name
        public let value: Attribute.Value
        public let primary: Bool
        public let unique: Bool

        public init(
            name: Attribute.Name, value: Attribute.Value,
            primary: Bool = false, unique: Bool = false
        ) {
            self.name = name
            self.value = value
            self.primary = primary
            self.unique = unique
        }
    }

    public struct RelationArgs {
        let name: Relation.Name
        let target: Entity.Name
        let many: Bool

        public init(name: Relation.Name, target: Entity.Name, many: Bool = false) {
            self.name = name
            self.target = target
            self.many = many
        }
    }

    public let name: Name
    public let allAttributes: [Attribute.Name: Attribute]
    public let customAttributes: [Attribute.Name: Attribute]
    public let relations: [Relation.Name: Relation]
    public let inverseRelationNames: [Entity.Name: Set<Relation.Name>]

    public let defaultCustomAttributeValues: [Attribute.Name: SQLValue]

    public init(
        name: Entity.Name, attributes: [AttributeArgs], relations: [RelationArgs],
        inverseRelationNames: [Entity.Name: Set<Relation.Name>]
    ) throws {
        self.name = name
        self.customAttributes = try Self.makeAttributes(attributes)
        self.allAttributes = try Self.makeAllAttributes(attributes)
        self.relations = try Self.makeRelations(relations, source: name)
        self.inverseRelationNames = inverseRelationNames

        defaultCustomAttributeValues = customAttributes.reduce(
            into: .init(),
            { partialResult, pair in
                partialResult[pair.key] = pair.value.defaultValue
            })
    }

    public var sqlForCreate: SQLUpdate {
        .createTable(name.table, columns: allAttributes.map { $0.value.column })
    }

    public var sqlForUpdate: SQLUpdate {
        .update(
            table: name.table, columnNames: allAttributes.map { $0.key.columnName },
            where: .expression(
                .compare(.pkId, .equal, .name(.pkId))))
    }

    public var sqlForInsert: SQLUpdate {
        let columnNames = allAttributes.compactMap {
            $0.key != .pkId ? $0.key.columnName : nil
        }
        return .insert(table: name.table, columnNames: columnNames)
    }
}

extension Entity {
    fileprivate static func makeAttributes(_ attributes: [AttributeArgs]) throws -> [Attribute.Name:
        Attribute]
    {
        try attributes.reduce(into: .init()) { partialResult, args in
            partialResult[args.name] = try .init(args: args)
        }
    }

    fileprivate static func makeAllAttributes(_ attributes: [AttributeArgs]) throws -> [Attribute
        .Name:
        Attribute]
    {
        let pkIdAttribute = Attribute.pkId
        let objectIdAttribute = Attribute.objectId
        let saveIdAttribute = Attribute.saveId
        let actionAttribute = Attribute.action

        var attributes = try makeAttributes(attributes)
        attributes[pkIdAttribute.name] = pkIdAttribute
        attributes[objectIdAttribute.name] = objectIdAttribute
        attributes[saveIdAttribute.name] = saveIdAttribute
        attributes[actionAttribute.name] = actionAttribute

        return attributes
    }

    fileprivate static func makeRelations(_ relations: [RelationArgs], source: Entity.Name) throws
        -> [Relation.Name: Relation]
    {
        try relations.reduce(into: .init()) { partialResult, value in
            partialResult[value.name] = try .init(args: value, source: source)
        }
    }
}

extension Entity: Codable {
    public init(from decoder: any Decoder) throws {
        throw ObjectDecodingError.unsupported
    }

    public func encode(to encoder: any Encoder) throws {
        throw ObjectEncodingError.unsupported
    }
}

extension Entity.Name {
    public var table: SQLTable { .init(rawValue) }
}

extension Attribute {
    fileprivate init(args: Entity.AttributeArgs) throws {
        try self.init(
            name: args.name, value: args.value, primary: args.primary, unique: args.unique)
    }
}

extension Relation {
    fileprivate init(args: Entity.RelationArgs, source: Entity.Name) throws {
        try self.init(name: args.name, source: source, target: args.target, many: args.many)
    }
}
