import Foundation

public protocol AttributesEncodable: Encodable {}
public protocol RelationsEncodable: Encodable {}
public protocol AttributesDecodable: Decodable {}
public protocol RelationsDecodable: Decodable {}

public protocol ObjectEncodable {
    associatedtype Id: RelationalId
    associatedtype Attributes: AttributesEncodable
    associatedtype Relations: RelationsEncodable

    var id: Id { get }
    var attributes: Attributes { get }
    var relations: Relations { get }
}

enum ObjectKey {
    static var id: String { "id" }
    static var attributes: String { "attributes" }
    static var relations: String { "relations" }
}

public protocol ObjectDecodable: Decodable {
    associatedtype Attributes: AttributesDecodable
    associatedtype Relations: RelationsDecodable
}

public typealias AttributesCodable = AttributesEncodable & AttributesDecodable
public typealias RelationsCodable = RelationsEncodable & RelationsDecodable

public protocol RelationalId: Hashable, Codable, Sendable {
    var rawId: ObjectId { get }
    init(rawId: ObjectId)
}

public protocol ObjectRelational {
    associatedtype Id: RelationalId
    associatedtype Relations

    var id: Id { get }
    var relations: Relations { get set }
}

public protocol ObjectModelable {
    static var tableName: String { get }
    static var entity: Model.EntityArgs { get }
}

extension ObjectModelable {
    public static var tableName: String { String(describing: self) }
    public static var table: SQLTable { .init(tableName) }
}

public protocol ObjectCodable: ObjectEncodable, ObjectDecodable, ObjectRelational, ObjectModelable,
    Sendable
{}

extension ObjectRelational {
    mutating func setRelations<T: ObjectRelational>(
        _ relationObjects: [T], forKeyPath keyPath: WritableKeyPath<Relations, [T.Id]>
    ) {
        relations[keyPath: keyPath] = relationObjects.map { $0.id }
    }

    mutating func appendRelation<T: ObjectRelational>(
        _ relationObject: T, forKeyPath keyPath: WritableKeyPath<Relations, [T.Id]>
    ) {
        relations[keyPath: keyPath].append(relationObject.id)
    }

    mutating func insertRelation<T: ObjectRelational>(
        _ relation: T, at index: Int, forKeyPath keyPath: WritableKeyPath<Relations, [T.Id]>
    ) {
        relations[keyPath: keyPath].insert(relation.id, at: index)
    }

    mutating func setRelation<T: ObjectRelational>(
        _ relationObject: T?, forKeyPath keyPath: WritableKeyPath<Relations, T.Id?>
    ) {
        relations[keyPath: keyPath] = relationObject.flatMap { $0.id }
    }
}
