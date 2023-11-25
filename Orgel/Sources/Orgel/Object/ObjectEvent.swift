import Foundation

public enum ObjectEvent {
    case fetched(object: SyncedObject)
    case loaded(object: SyncedObject)
    case removed(object: SyncedObject)
    case cleared(object: SyncedObject)
    case attributeUpdated(object: SyncedObject, name: Attribute.Name, value: SQLValue)
    case relationInserted(object: SyncedObject, name: Relation.Name, indices: [Int])
    case relationRemoved(object: SyncedObject, name: Relation.Name, indices: [Int])
    case relationReplaced(object: SyncedObject, name: Relation.Name)
}

extension ObjectEvent {
    public var isChanged: Bool {
        switch self {
        case .removed, .attributeUpdated, .relationInserted, .relationRemoved, .relationReplaced:
            return true
        case .fetched, .loaded, .cleared:
            return false
        }
    }

    public var changedObject: SyncedObject? {
        switch self {
        case let .removed(object), let .attributeUpdated(object, _, _),
            let .relationInserted(object, _, _),
            let .relationRemoved(object, _, _), let .relationReplaced(object, _):
            return object
        case .fetched, .loaded, .cleared:
            return nil
        }
    }
}
