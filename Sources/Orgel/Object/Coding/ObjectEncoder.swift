import Foundation

enum ObjectEncodingError: Error {
    case unsupported
    case attributeNotFound
    case relationNotFound
    case relationIdsOverflow
    case typeMismatch
}

struct EncodedObjectData: Sendable {
    let id: ObjectId
    let attributes: [Attribute.Name: SQLValue]
    let relations: [Relation.Name: [ObjectId]]
}

final class ObjectEncoder {
    func encode(_ object: some ObjectEncodable, entity: Entity) throws -> EncodedObjectData {
        let destination = EncodingDestination(entity: entity)

        try object.attributes.encode(to: AttributesEncoder(destination: destination))
        try object.relations.encode(to: RelationsEncoder(destination: destination))

        return .init(
            id: object.id.rawId,
            attributes: destination.attributes,
            relations: destination.relations
        )
    }
}

private final class EncodingDestination {
    let entity: Entity
    private(set) var attributes: [Attribute.Name: SQLValue]
    private(set) var relations: [Relation.Name: [ObjectId]] = [:]

    init(entity: Entity) {
        self.entity = entity

        self.attributes = entity.customAttributes.reduce(into: .init()) {
            partialResult, attribute in
            partialResult[attribute.key] = attribute.value.defaultValue
        }
    }

    fileprivate func setAttributeValue(_ value: SQLValue, forKey key: CodingKey) throws {
        let attributeName = Attribute.Name(key.stringValue)

        if entity.customAttributes.keys.contains(attributeName) {
            attributes[attributeName] = value
        } else {
            throw ObjectEncodingError.attributeNotFound
        }
    }

    fileprivate func setRelationIds(_ ids: [ObjectId], forKey key: CodingKey) throws {
        let relationName = Relation.Name(key.stringValue)

        if let relation = entity.relations[relationName] {
            if !relation.many && ids.count > 1 {
                throw ObjectEncodingError.relationIdsOverflow
            }
            relations[relationName] = ids
        } else {
            throw ObjectEncodingError.relationNotFound
        }
    }
}

private final class AttributesEncoder: Encoder {
    struct Container<Key: CodingKey>: KeyedEncodingContainerProtocol {
        let destination: EncodingDestination
        let codingPath: [CodingKey]

        mutating func encodeNil(forKey key: Key) throws {
            try destination.setAttributeValue(.null, forKey: key)
        }

        mutating func encode(_ value: Bool, forKey key: Key) throws {
            try destination.setAttributeValue(.integer(value ? 1 : 0), forKey: key)
        }

        mutating func encode(_ value: String, forKey key: Key) throws {
            try destination.setAttributeValue(.text(.init(value)), forKey: key)
        }

        mutating func encode(_ value: Double, forKey key: Key) throws {
            try destination.setAttributeValue(.real(value), forKey: key)
        }

        mutating func encode(_ value: Float, forKey key: Key) throws {
            try destination.setAttributeValue(.real(.init(value)), forKey: key)
        }

        mutating func encode(_ value: Int, forKey key: Key) throws {
            try destination.setAttributeValue(.integer(.init(value)), forKey: key)
        }

        mutating func encode(_ value: Int8, forKey key: Key) throws {
            try destination.setAttributeValue(.integer(.init(value)), forKey: key)
        }

        mutating func encode(_ value: Int16, forKey key: Key) throws {
            try destination.setAttributeValue(.integer(.init(value)), forKey: key)
        }

        mutating func encode(_ value: Int32, forKey key: Key) throws {
            try destination.setAttributeValue(.integer(.init(value)), forKey: key)
        }

        mutating func encode(_ value: Int64, forKey key: Key) throws {
            try destination.setAttributeValue(.integer(.init(value)), forKey: key)
        }

        mutating func encode(_ value: UInt, forKey key: Key) throws {
            try destination.setAttributeValue(.integer(.init(value)), forKey: key)
        }

        mutating func encode(_ value: UInt8, forKey key: Key) throws {
            try destination.setAttributeValue(.integer(.init(value)), forKey: key)
        }

        mutating func encode(_ value: UInt16, forKey key: Key) throws {
            try destination.setAttributeValue(.integer(.init(value)), forKey: key)
        }

        mutating func encode(_ value: UInt32, forKey key: Key) throws {
            try destination.setAttributeValue(.integer(.init(value)), forKey: key)
        }

        mutating func encode(_ value: UInt64, forKey key: Key) throws {
            try destination.setAttributeValue(.integer(.init(value)), forKey: key)
        }

        mutating func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
            if let data = value as? Data {
                try destination.setAttributeValue(.blob(data), forKey: key)
            } else {
                throw ObjectEncodingError.unsupported
            }
        }

        mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key)
            -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey
        {
            fatalError()
        }

        mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
            fatalError()
        }

        mutating func superEncoder() -> Encoder {
            fatalError()
        }

        mutating func superEncoder(forKey key: Key) -> Encoder {
            fatalError()
        }

    }

    let destination: EncodingDestination
    let codingPath: [CodingKey] = []
    let userInfo: [CodingUserInfoKey: Any] = [:]

    init(destination: EncodingDestination) {
        self.destination = destination
    }

    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key>
    where Key: CodingKey {
        KeyedEncodingContainer(
            Container(destination: destination, codingPath: codingPath))
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        fatalError()
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        fatalError()
    }
}

private final class RelationsEncoder: Encoder {
    struct Container<Key: CodingKey>: KeyedEncodingContainerProtocol {
        let destination: EncodingDestination
        let codingPath: [CodingKey] = []

        mutating func encodeNil(forKey key: Key) throws {
            throw ObjectEncodingError.unsupported
        }

        mutating func encode<T>(_ value: T, forKey key: Key) throws where T: Encodable {
            if let relationIds = value as? [any RelationalId] {
                try destination.setRelationIds(relationIds.map(\.rawId), forKey: key)
            } else if let relationId = value as? any RelationalId {
                try destination.setRelationIds([relationId.rawId], forKey: key)
            } else {
                throw ObjectEncodingError.typeMismatch
            }
        }

        mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key)
            -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey
        {
            fatalError()
        }

        mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
            fatalError()
        }

        mutating func superEncoder() -> Encoder {
            fatalError()
        }

        mutating func superEncoder(forKey key: Key) -> Encoder {
            fatalError()
        }
    }

    let destination: EncodingDestination
    let codingPath: [CodingKey] = []
    let userInfo: [CodingUserInfoKey: Any] = [:]

    init(destination: EncodingDestination) {
        self.destination = destination
    }

    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key>
    where Key: CodingKey {
        KeyedEncodingContainer(Container(destination: destination))
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        fatalError()
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        fatalError()
    }
}
