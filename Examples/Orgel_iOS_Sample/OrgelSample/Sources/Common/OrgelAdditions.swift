import Orgel

extension SyncedObject {
    var modelCustomAttributes: [Attribute] {
        entity.customAttributes.map(\.value)
    }

    var modelRelations: [Relation] {
        entity.relations.map(\.value)
    }

    func attributeValue(forName name: Attribute.Name) -> SQLValue {
        attributes[name] ?? .null
    }

    func setAttributeEditingStringValue(_ stringValue: String, forName name: Attribute.Name) {
        guard let modelAttribute = entity.customAttributes[name] else { return }
        switch modelAttribute.value {
        case .integer:
            guard let integerValue = Int64(stringValue) else { return }
            setAttributeValue(.integer(integerValue), forName: name)
        case .real:
            guard let realValue = Double(stringValue) else { return }
            setAttributeValue(.real(realValue), forName: name)
        case .text:
            setAttributeValue(.text(stringValue), forName: name)
        case .blob:
            break
        }
    }

    func attributeEditingStringValue(forName name: Attribute.Name) -> String {
        attributeValue(forName: name).editingStringValue
    }
}

extension SQLValue {
    var editingStringValue: String {
        switch self {
        case let .integer(value):
            return String(value)
        case let .real(value):
            return String(value)
        case let .text(value):
            return value
        case .blob, .null:
            return ""
        }
    }
}

extension SQLColumn.Name {
    static let objectId: SQLColumn.Name = .init("obj_id")
}
