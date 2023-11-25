import Foundation

extension [Entity.Name: [SyncedObject]] {
    @MainActor
    var relationStableIds: [Entity.Name: Set<StableId>] {
        reduce(
            into: .init(),
            { (partialResult, pair) in
                for object in pair.value {
                    partialResult.formUnion(object.relationStableIds)
                }
            })
    }
}

extension [SyncedObject] {
    @MainActor
    var relationStableIds: [Entity.Name: Set<StableId>] {
        reduce(
            into: .init(),
            { partialResult, object in
                partialResult.formUnion(object.relationStableIds)
            })
    }
}

extension [Entity.Name: Set<StableId>] {
    mutating func formUnion(_ other: [Entity.Name: Set<StableId>]) {
        for (entityName, ids) in other {
            if self[entityName] == nil {
                self[entityName] = ids
            } else {
                self[entityName]!.formUnion(ids)
            }
        }
    }
}

extension [Entity.Name: [TemporaryId: SyncedObject]] {
    typealias TemporaryEnumerateHandler = (
        _ entityName: Entity.Name, _ temporaryId: TemporaryId, _ object: SyncedObject
    ) -> Void

    func enumerateEntity(name: Entity.Name, handler: TemporaryEnumerateHandler) {
        guard let objects = self[name] else { return }

        for (temporaryId, object) in objects {
            handler(name, temporaryId, object)
        }
    }

    func enumerate(handler: TemporaryEnumerateHandler) {
        for (entityName, objects) in self {
            for (temporaryId, object) in objects {
                handler(entityName, temporaryId, object)
            }
        }
    }

    mutating func removeEntityIfEmpty(name: Entity.Name) {
        if self[name]?.isEmpty ?? false {
            self[name] = nil
        }
    }
}

extension [Entity.Name: [StableId: Weak<SyncedObject>]] {
    typealias StableEnumerateHandler = (
        _ entityName: Entity.Name, _ stableId: StableId, _ object: SyncedObject
    ) -> Void

    func enumerateEntity(name: Entity.Name, handler: StableEnumerateHandler) {
        guard let objects = self[name] else { return }

        for (stableId, weakObject) in objects {
            if let object = weakObject.value {
                handler(name, stableId, object)
            }
        }
    }

    func enumerate(handler: StableEnumerateHandler) {
        for (entityName, objects) in self {
            for (stableId, weakObject) in objects {
                if let object = weakObject.value {
                    handler(entityName, stableId, object)
                }
            }
        }
    }

    mutating func setObject(
        _ object: SyncedObject, stableId: StableId, entityName: Entity.Name
    ) {
        if self[entityName] == nil {
            self[entityName] = .init()
        }

        self[entityName]![stableId] = .init(value: object)
    }
}
