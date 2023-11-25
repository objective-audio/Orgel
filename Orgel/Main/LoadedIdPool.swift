import Foundation

actor LoadedIdPool {
    private var idsByTemporary: [Entity.Name: [TemporaryId: LoadingObjectId]] = [:]
    private var idsByStable: [Entity.Name: [StableId: LoadingObjectId]] = [:]

    func get(for temporary: TemporaryId, entityName: Entity.Name) -> LoadingObjectId? {
        idsByTemporary[entityName]?[temporary]
    }

    func get(for stable: StableId, entityName: Entity.Name) -> LoadingObjectId? {
        idsByStable[entityName]?[stable]
    }

    func set(stable: StableId, temporary: TemporaryId, entityName: Entity.Name) {
        let objectId = LoadingObjectId.both(stable: stable, temporary: temporary)

        if idsByTemporary[entityName] == nil {
            idsByTemporary[entityName] = [:]
        }

        if idsByStable[entityName] == nil {
            idsByStable[entityName] = [:]
        }

        idsByTemporary[entityName]?[temporary] = objectId
        idsByStable[entityName]?[stable] = objectId
    }

    func clear() {
        idsByTemporary = [:]
        idsByStable = [:]
    }
}

extension LoadedIdPool {
    func set(from loadingObjectDatas: [Entity.Name: [LoadingObjectData]]) {
        for (entityName, entityObjectDatas) in loadingObjectDatas {
            for objectData in entityObjectDatas {
                if case let .both(stable, temporary) = objectData.id {
                    set(stable: stable, temporary: temporary, entityName: entityName)
                }
            }
        }
    }

    func idReplacedObjectDatas(
        _ loadingObjectDatas: [Entity.Name: [LoadingObjectData]], model: Model
    )
        -> [Entity
        .Name: [LoadingObjectData]]
    {
        loadingObjectDatas.reduce(into: .init()) { partialResult, pair in
            let entityName = pair.key
            partialResult[entityName] = pair.value.map {
                let resultId =
                    if case let .stable(stableId) = $0.id,
                        let pooledId = get(for: stableId, entityName: entityName)
                    {
                        pooledId
                    } else {
                        $0.id
                    }

                if let values = $0.values {
                    let relations = $0.relations.reduce(into: [Relation.Name: [LoadingObjectId]]())
                    {
                        partialResult, pair in
                        let relationName: Relation.Name = pair.key

                        guard
                            let relationEntityName = model.entities[entityName]?.relations[
                                relationName]?.target
                        else {
                            fatalError()
                        }

                        partialResult[relationName] = pair.value.map {
                            if case let .stable(stableId) = $0,
                                let pooledId = get(for: stableId, entityName: relationEntityName)
                            {
                                pooledId
                            } else {
                                $0
                            }
                        }
                    }

                    return .init(
                        id: resultId,
                        values: .init(
                            pkId: values.pkId, saveId: values.saveId, action: values.action,
                            attributes: values.attributes,
                            relations: relations))
                } else {
                    return .init(id: resultId, values: nil)
                }
            }
        }
    }
}
