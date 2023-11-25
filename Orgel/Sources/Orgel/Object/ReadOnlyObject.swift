import Foundation

public struct ReadOnlyObject: Sendable {
    public let entity: Entity
    private let data: LoadingObjectData
    var loadingId: LoadingObjectId { data.id }
    public var id: ObjectId { loadingId.objectId }

    init(entity: Entity, data: LoadingObjectData) {
        self.data = data
        self.entity = entity
    }
}

extension ReadOnlyObject {
    public func attributeValue(forName name: Attribute.Name) -> SQLValue {
        precondition(validateAttributeName(name))
        precondition(name != .objectId)
        precondition(name != .action)

        return data.attributes[name] ?? .null
    }

    public func relationIds(forName name: Relation.Name) -> [ObjectId] {
        precondition(validateRelationName(name))

        return data.relations[name]?.map(\.objectId) ?? []
    }

    public func typed<T: ObjectCodable>(_ type: T.Type) throws -> T {
        try ObjectDecoder().decode(type, from: data, entity: entity)
    }
}

extension ReadOnlyObject {
    var saveId: Int64? {
        data.values?.saveId
    }

    var action: ObjectAction? {
        data.values?.action
    }
}

extension ReadOnlyObject {
    private func validateAttributeName(_ name: Attribute.Name) -> Bool {
        entity.allAttributes[name] != nil
    }

    private func validateRelationName(_ name: Relation.Name) -> Bool {
        entity.relations[name] != nil
    }

    private func validateRelationId(_ id: ObjectId) -> Bool {
        if let stable = id.stable, stable.rawValue <= 0 {
            return false
        } else {
            return true
        }
    }

    private func validateRelationId(_ id: SyncedObjectId) -> Bool {
        validateRelationId(id.objectId)
    }

    private func validateRelationIds(_ ids: [ObjectId]) -> Bool {
        for id in ids {
            if !validateRelationId(id) {
                return false
            }
        }
        return true
    }

    private func validateRelationIds(_ ids: [SyncedObjectId]) -> Bool {
        validateRelationIds(ids.map(\.objectId))
    }
}
