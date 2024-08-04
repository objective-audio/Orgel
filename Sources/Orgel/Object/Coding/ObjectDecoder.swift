import Foundation

enum ObjectDecodingError: Error {
    case attributeNotFound
    case relationNotFound
    case valueNotFound
    case keyNotFound
    case typeMismatch
    case relationIdOverflow
    case getRelationIdsFailed
    case typeNotFound
    case sourceNotFound
    case relationIndexOverflow
    case unsupported
}

final class ObjectDecoder: Decoder {
    private struct KeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
        let source: DecodingSource
        let codingPath: [any CodingKey] = []
        var allKeys: [Key] { fatalError() }

        func contains(_ key: Key) -> Bool {
            false
        }

        func decodeNil(forKey key: Key) throws -> Bool {
            throw ObjectDecodingError.unsupported
        }

        func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
            switch key.stringValue {
            case ObjectKey.id:
                return try T(
                    from: ObjectRelationalIdDecoder(objectId: source.objectId))
            case ObjectKey.attributes:
                return try T(
                    from: AttributesDecoder(source: source, codingPath: codingPath + [key]))
            case ObjectKey.relations:
                return try T(from: RelationsDecoder(source: source, codingPath: codingPath + [key]))
            default:
                throw ObjectDecodingError.keyNotFound
            }
        }

        func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws
            -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey
        {
            throw ObjectDecodingError.unsupported
        }

        func nestedUnkeyedContainer(forKey key: Key) throws -> any UnkeyedDecodingContainer {
            throw ObjectDecodingError.unsupported
        }

        func superDecoder() throws -> any Decoder {
            throw ObjectDecodingError.unsupported
        }

        func superDecoder(forKey key: Key) throws -> any Decoder {
            throw ObjectDecodingError.unsupported
        }
    }

    let codingPath: [any CodingKey] = []
    let userInfo: [CodingUserInfoKey: Any] = [:]

    private var source: DecodingSource?

    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        guard let source else {
            throw ObjectDecodingError.sourceNotFound
        }

        return KeyedDecodingContainer(KeyedContainer(source: source))
    }

    func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
        throw ObjectDecodingError.unsupported
    }

    func singleValueContainer() throws -> any SingleValueDecodingContainer {
        throw ObjectDecodingError.unsupported
    }

    func decode<T: ObjectDecodable>(
        _ type: T.Type, from objectData: LoadingObjectData, entity: Entity
    ) throws -> T {
        source = .init(
            objectId: objectData.id.objectId, attributes: objectData.attributes,
            relations: objectData.relations.reduce(
                into: .init(),
                { partialResult, pair in
                    partialResult[pair.key] = pair.value.map(\.objectId)
                }), entity: entity)
        defer { source = nil }

        return try T(from: self)
    }

    func decode<T: ObjectDecodable>(
        _ type: T.Type, from objectData: SavingObjectData, entity: Entity
    ) throws -> T {
        source = .init(
            objectId: objectData.id, attributes: objectData.attributes,
            relations: objectData.relations, entity: entity)
        defer { source = nil }

        return try T(from: self)
    }
}

private struct DecodingSource {
    let objectId: ObjectId
    let attributes: [Attribute.Name: SQLValue]
    let relations: [Relation.Name: [ObjectId]]
    let entity: Entity

    private func getAttributeValue(forKey key: any CodingKey, type: SQLValueType) throws -> SQLValue
    {
        let attributeName = Attribute.Name(key.stringValue)

        guard let attribute = entity.customAttributes[attributeName] else {
            throw ObjectDecodingError.attributeNotFound
        }

        guard attribute.value.type == type else {
            throw ObjectDecodingError.typeMismatch
        }

        if let value = attributes[attributeName] {
            return value
        } else if !attribute.defaultValue.isNull {
            return attribute.defaultValue
        } else {
            throw ObjectDecodingError.valueNotFound
        }
    }

    fileprivate func getAttributeIntegerValue(forKey key: any CodingKey) throws -> Int64 {
        let value = try getAttributeValue(forKey: key, type: .integer)

        guard let integerValue = value.integerValue else {
            throw ObjectDecodingError.typeMismatch
        }

        return integerValue
    }

    fileprivate func getAttributeTextValue(forKey key: any CodingKey) throws -> String {
        let value = try getAttributeValue(forKey: key, type: .text)

        guard let textValue = value.textValue else {
            throw ObjectDecodingError.typeMismatch
        }

        return textValue
    }

    fileprivate func getAttributeRealValue(forKey key: any CodingKey) throws -> Double {
        let value = try getAttributeValue(forKey: key, type: .real)

        guard let realValue = value.realValue else {
            throw ObjectDecodingError.typeMismatch
        }

        return realValue
    }

    fileprivate func getAttributeBlobValue(forKey key: any CodingKey) throws -> Data {
        let value = try getAttributeValue(forKey: key, type: .blob)

        guard let blobValue = value.blobValue else {
            throw ObjectDecodingError.typeMismatch
        }

        return blobValue
    }

    fileprivate func containsAttributeValue(forKey key: any CodingKey) -> Bool {
        if let value = attributes[.init(key.stringValue)], !value.isNull {
            return true
        } else if let modelAttribute = entity.customAttributes[.init(key.stringValue)],
            !modelAttribute.defaultValue.isNull
        {
            return true
        } else {
            return false
        }
    }

    fileprivate func allowsNilAttributeValue(forKey key: any CodingKey) -> Bool {
        // nullが許可されていなければfalseを返す
        guard let modelAttribute = entity.customAttributes[.init(key.stringValue)],
            !modelAttribute.notNull
        else {
            return false
        }

        if let value = attributes[.init(key.stringValue)] {
            if value.isNull {
                // 明示的にnilがセットされていればnilにできる
                return true
            } else {
                // 値が存在しているのでnilにできない
                return false
            }
        } else {
            // nullは許容されているが値はセットされていない
            if modelAttribute.defaultValue.isNull {
                // デフォルトがnullなのでnilにできる
                return true
            } else {
                // デフォルトが設定されているのでnilにできない
                return false
            }
        }
    }

    fileprivate func containsRelation(forKey key: any CodingKey) -> Bool {
        guard let value = relations[.init(key.stringValue)], !value.isEmpty else {
            return false
        }
        return true
    }

    fileprivate func getRelationIds(forKey key: any CodingKey) throws -> [ObjectId] {
        let relationName = Relation.Name(key.stringValue)
        guard let relation = entity.relations[relationName] else {
            throw ObjectDecodingError.relationNotFound
        }

        guard let ids = relations[relationName] else {
            return []
        }

        if !relation.many, ids.count > 1 {
            throw ObjectDecodingError.relationIdOverflow
        }

        return ids.map { $0 }
    }
}

private final class AttributesDecoder: Decoder {
    struct KeyedCotainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
        let source: DecodingSource
        let codingPath: [any CodingKey]
        var allKeys: [Key] { fatalError() }

        func contains(_ key: Key) -> Bool {
            source.containsAttributeValue(forKey: key)
        }

        func decodeNil(forKey key: Key) throws -> Bool {
            source.allowsNilAttributeValue(forKey: key)
        }

        func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
            (try source.getAttributeIntegerValue(forKey: key)) != 0
        }

        func decode(_ type: String.Type, forKey key: Key) throws -> String {
            try source.getAttributeTextValue(forKey: key)
        }

        func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
            try source.getAttributeRealValue(forKey: key)
        }

        func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
            .init(try source.getAttributeRealValue(forKey: key))
        }

        func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
            .init(try source.getAttributeIntegerValue(forKey: key))
        }

        func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
            .init(try source.getAttributeIntegerValue(forKey: key))
        }

        func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
            .init(try source.getAttributeIntegerValue(forKey: key))
        }

        func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
            .init(try source.getAttributeIntegerValue(forKey: key))
        }

        func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
            .init(try source.getAttributeIntegerValue(forKey: key))
        }

        func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
            .init(try source.getAttributeIntegerValue(forKey: key))
        }

        func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
            .init(try source.getAttributeIntegerValue(forKey: key))
        }

        func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
            .init(try source.getAttributeIntegerValue(forKey: key))
        }

        func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
            .init(try source.getAttributeIntegerValue(forKey: key))
        }

        func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
            .init(try source.getAttributeIntegerValue(forKey: key))
        }

        func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T: Decodable {
            if type == Data.self {
                return (try source.getAttributeBlobValue(forKey: key)) as! T
            } else {
                throw ObjectDecodingError.typeNotFound
            }
        }

        func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws
            -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey
        {
            throw ObjectDecodingError.unsupported
        }

        func nestedUnkeyedContainer(forKey key: Key) throws -> any UnkeyedDecodingContainer {
            throw ObjectDecodingError.unsupported
        }

        func superDecoder() throws -> any Decoder {
            throw ObjectDecodingError.unsupported
        }

        func superDecoder(forKey key: Key) throws -> any Decoder {
            throw ObjectDecodingError.unsupported
        }
    }

    let source: DecodingSource
    let codingPath: [any CodingKey]
    private(set) var userInfo: [CodingUserInfoKey: Any] = [:]

    init(source: DecodingSource, codingPath: [any CodingKey]) {
        self.source = source
        self.codingPath = codingPath
    }

    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        KeyedDecodingContainer(KeyedCotainer(source: source, codingPath: codingPath))
    }

    func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
        throw ObjectDecodingError.unsupported
    }

    func singleValueContainer() throws -> any SingleValueDecodingContainer {
        throw ObjectDecodingError.unsupported
    }
}

private final class RelationsDecoder: Decoder {
    struct KeyedCotainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
        let source: DecodingSource
        let codingPath: [any CodingKey]
        var allKeys: [Key] { fatalError() }

        func contains(_ key: Key) -> Bool {
            source.containsRelation(forKey: key)
        }

        func decodeNil(forKey key: Key) throws -> Bool {
            !source.containsRelation(forKey: key)
        }

        func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
            return try T(from: RelationIdsDecoder(source: source, codingPath: codingPath + [key]))
        }

        func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws
            -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey
        {
            throw ObjectDecodingError.unsupported
        }

        func nestedUnkeyedContainer(forKey key: Key) throws -> any UnkeyedDecodingContainer {
            throw ObjectDecodingError.unsupported
        }

        func superDecoder() throws -> any Decoder {
            throw ObjectDecodingError.unsupported
        }

        func superDecoder(forKey key: Key) throws -> any Decoder {
            throw ObjectDecodingError.unsupported
        }
    }

    let source: DecodingSource
    let codingPath: [any CodingKey]
    let userInfo: [CodingUserInfoKey: Any] = [:]

    init(source: DecodingSource, codingPath: [any CodingKey]) {
        self.source = source
        self.codingPath = codingPath
    }

    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        KeyedDecodingContainer(
            KeyedCotainer(source: source, codingPath: codingPath))
    }

    func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
        throw ObjectDecodingError.unsupported
    }

    func singleValueContainer() throws -> any SingleValueDecodingContainer {
        throw ObjectDecodingError.unsupported
    }
}

private final class RelationIdsDecoder: Decoder {
    struct KeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
        let source: DecodingSource
        let codingPath: [any CodingKey]
        var allKeys: [Key] { fatalError() }

        func contains(_ key: Key) -> Bool {
            fatalError()
        }

        func decodeNil(forKey key: Key) throws -> Bool {
            throw ObjectDecodingError.unsupported
        }

        func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
            guard let relationIdsKey = codingPath.last else {
                fatalError()
            }

            let ids = try source.getRelationIds(forKey: relationIdsKey)

            if type is ObjectId.Type, let id = ids.first {
                return id as! T
            } else {
                throw ObjectDecodingError.typeMismatch
            }
        }

        func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws
            -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey
        {
            throw ObjectDecodingError.unsupported
        }

        func nestedUnkeyedContainer(forKey key: Key) throws -> any UnkeyedDecodingContainer {
            throw ObjectDecodingError.unsupported
        }

        func superDecoder() throws -> any Decoder {
            throw ObjectDecodingError.unsupported
        }

        func superDecoder(forKey key: Key) throws -> any Decoder {
            throw ObjectDecodingError.unsupported
        }
    }

    struct UnkeyedContainer: UnkeyedDecodingContainer {
        let source: DecodingSource
        let codingPath: [any CodingKey]
        var count: Int? {
            guard let relationIds else { return 0 }
            return relationIds.count
        }
        var isAtEnd: Bool {
            guard let count else { return true }
            return count <= currentIndex
        }
        var currentIndex: Int = 0

        private var relationIds: [ObjectId]? {
            guard let key = codingPath.last, let ids = try? source.getRelationIds(forKey: key)
            else {
                return nil
            }
            return ids
        }

        mutating func decodeNil() throws -> Bool {
            throw ObjectDecodingError.unsupported
        }

        mutating func decode<T: Decodable>(_ type: T.Type) throws -> T {
            defer { currentIndex += 1 }

            guard let relationIds, currentIndex < relationIds.count else {
                throw ObjectDecodingError.relationIdOverflow
            }

            return try T(from: ObjectRelationalIdDecoder(objectId: relationIds[currentIndex]))
        }

        mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws
            -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey
        {
            throw ObjectDecodingError.unsupported
        }

        mutating func nestedUnkeyedContainer() throws -> any UnkeyedDecodingContainer {
            throw ObjectDecodingError.unsupported
        }

        mutating func superDecoder() throws -> any Decoder {
            throw ObjectDecodingError.unsupported
        }
    }

    let source: DecodingSource
    let codingPath: [any CodingKey]
    var userInfo: [CodingUserInfoKey: Any] { fatalError() }

    init(source: DecodingSource, codingPath: [any CodingKey]) {
        self.source = source
        self.codingPath = codingPath
    }

    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        KeyedDecodingContainer(KeyedContainer(source: source, codingPath: codingPath))
    }

    func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
        UnkeyedContainer(source: source, codingPath: codingPath)
    }

    func singleValueContainer() throws -> any SingleValueDecodingContainer {
        throw ObjectDecodingError.unsupported
    }
}

private final class ObjectRelationalIdDecoder: Decoder {
    struct KeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
        let objectId: ObjectId
        var codingPath: [any CodingKey] { fatalError() }
        var allKeys: [Key] { fatalError() }

        func contains(_ key: Key) -> Bool {
            fatalError()
        }

        func decodeNil(forKey key: Key) throws -> Bool {
            throw ObjectDecodingError.unsupported
        }

        func decode<T: Decodable>(_ type: T.Type, forKey _: Key) throws -> T {
            if type is ObjectId.Type {
                return objectId as! T
            } else {
                throw ObjectDecodingError.typeMismatch
            }
        }

        func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws
            -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey
        {
            throw ObjectDecodingError.unsupported
        }

        func nestedUnkeyedContainer(forKey key: Key) throws -> any UnkeyedDecodingContainer {
            throw ObjectDecodingError.unsupported
        }

        func superDecoder() throws -> any Decoder {
            throw ObjectDecodingError.unsupported
        }

        func superDecoder(forKey key: Key) throws -> any Decoder {
            throw ObjectDecodingError.unsupported
        }
    }

    let objectId: ObjectId
    var codingPath: [any CodingKey] { fatalError() }
    var userInfo: [CodingUserInfoKey: Any] { fatalError() }

    init(objectId: ObjectId) {
        self.objectId = objectId
    }

    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        KeyedDecodingContainer(KeyedContainer(objectId: objectId))
    }

    func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
        throw ObjectDecodingError.unsupported
    }

    func singleValueContainer() throws -> any SingleValueDecodingContainer {
        throw ObjectDecodingError.unsupported
    }
}
