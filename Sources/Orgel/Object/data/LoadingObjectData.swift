import Foundation

struct LoadingObjectData {
    struct Values {
        let pkId: Int64
        let saveId: Int64
        let action: ObjectAction
        let attributes: [Attribute.Name: SQLValue]
        fileprivate(set) var relations: [Relation.Name: [LoadingObjectId]]
    }

    let id: LoadingObjectId
    // undoしてinsert前だとnilになる
    private(set) var values: Values?
}

extension LoadingObjectData {
    init(
        id: LoadingObjectId, attributes: [Attribute.Name: SQLValue],
        relations: [Relation.Name: [LoadingObjectId]]
    ) {
        self.id = id

        var attributes = attributes

        if let pkId = attributes[.pkId]?.integerValue,
            let saveId = attributes[.saveId]?.integerValue,
            let action = attributes[.action]?.textValue.flatMap(ObjectAction.init(rawValue:))
        {
            attributes[.objectId] = nil
            attributes[.pkId] = nil
            attributes[.saveId] = nil
            attributes[.action] = nil

            values = .init(
                pkId: pkId, saveId: saveId, action: action,
                attributes: attributes, relations: relations)
        } else {
            values = nil
        }
    }

    init(
        attributes: [Attribute.Name: SQLValue], relations: [Relation.Name: [LoadingObjectId]]
    ) throws {
        enum MakeError: Error {
            case getStableIdFailed
        }

        guard let objectId = attributes[.objectId]?.integerValue
        else {
            throw MakeError.getStableIdFailed
        }

        let id = LoadingObjectId.stable(.init(objectId))

        self = .init(id: id, attributes: attributes, relations: relations)
    }
}

extension LoadingObjectData {
    var attributes: [Attribute.Name: SQLValue] { values?.attributes ?? [:] }
    var relations: [Relation.Name: [LoadingObjectId]] { values?.relations ?? [:] }

    mutating func updateRelations(
        _ relations: [LoadingObjectId], forName name: Relation.Name
    ) {
        values?.relations[name] = relations
    }
}
