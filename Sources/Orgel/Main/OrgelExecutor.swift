import Foundation

public actor OrgelExecutor {
    let model: Model
    let queue: SerialTaskQueue
    let data: OrgelData
    let sqliteExecutor: SQLiteExecutor
    let loadingIdPool: LoadingIdPool

    init(model: Model, data: OrgelData, sqliteExecutor: SQLiteExecutor) {
        self.model = model
        self.queue = .init()
        self.data = data
        self.sqliteExecutor = sqliteExecutor
        self.loadingIdPool = .init()
    }

    public func insertSyncedObjects(
        values: [Entity.Name: [[Attribute.Name: SQLValue]]]
    ) async throws
        -> SyncedResultData
    {
        let taskId = await queue.addTask()
        return try await queue.execute(id: taskId) {
            let result = try await sqliteExecutor.insertObjects(model: model, values: values)
            return try await data.loadInserted(result)
        }
    }

    public func insertSyncedObjects(
        counts: [Entity.Name: Int]
    ) async throws -> SyncedResultData {
        // エンティティごとの数を指定してデータベースにオブジェクトを挿入する

        var values: [Entity.Name: [[Attribute.Name: SQLValue]]] = [:]

        for (entityName, count) in counts {
            values[entityName] = .init(repeating: [:], count: count)
        }

        return try await insertSyncedObjects(values: values)
    }

    public func fetchSyncedObjects(_ option: FetchOption) async throws -> SyncedResultData {
        let taskId = await queue.addTask()
        return try await queue.execute(id: taskId) {
            let objectDatas = try await sqliteExecutor.fetchObjectDatas(option, model: model)
            let idReplacedObjectDatas = await loadingIdPool.idReplacedObjectDatas(
                objectDatas, model: model)
            return try await data.loadFetched(objectDatas: idReplacedObjectDatas)
        }
    }

    public func fetchReadOnlyObjects(_ option: FetchOption) async throws -> ReadOnlyResultData {
        let taskId = await queue.addTask()
        return try await queue.execute(id: taskId) {
            let objectDatas = try await sqliteExecutor.fetchObjectDatas(option, model: model)
            let idReplacedObjectDatas = await loadingIdPool.idReplacedObjectDatas(
                objectDatas, model: model)
            return try makeReadOnlyObjects(objectDatas: idReplacedObjectDatas)
        }
    }

    nonisolated
        private func makeReadOnlyObjects(objectDatas: [Entity.Name: [LoadingObjectData]]) throws
        -> ReadOnlyResultData
    {
        enum MakeReadOnlyError: Error {
            case entityNotFound
        }

        var objects: ReadOnlyResultData = [:]

        for (entityName, entityDatas) in objectDatas {
            guard let entity = model.entities[entityName] else {
                throw MakeReadOnlyError.entityNotFound
            }

            var entityOrder: [ObjectId] = []
            var entityObjects: [ObjectId: ReadOnlyObject] = [:]
            entityOrder.reserveCapacity(entityDatas.count)
            entityObjects.reserveCapacity(entityDatas.count)

            for objectData in entityDatas {
                let objectId = objectData.id.objectId
                entityOrder.append(objectId)
                entityObjects[objectId] = .init(entity: entity, data: objectData)
            }

            objects[entityName] = .init(order: entityOrder, objects: entityObjects)
        }

        return objects
    }

    public func clear() async throws {
        let taskId = await queue.addTask()
        return try await queue.execute(id: taskId) {
            let info = try await sqliteExecutor.clear(model: model)
            await loadingIdPool.clear()
            await data.loadCleared(info: info)
        }
    }

    public func save() async throws -> SyncedResultData {
        let taskId = await queue.addTask()
        return try await queue.execute(id: taskId) {
            let changedDatas = try await data.changedObjectDatasForSave()
            let result = try await sqliteExecutor.save(model: model, changedDatas: changedDatas)
            await loadingIdPool.set(from: result.savedDatas)
            return try await data.loadSaved(result)
        }
    }

    public func revert(saveId: Int64) async throws -> SyncedResultData {
        let taskId = await queue.addTask()
        return try await queue.execute(id: taskId) {
            let result = try await sqliteExecutor.revert(model: model, revertSaveId: saveId)
            let idReplacedObjectDatas = await loadingIdPool.idReplacedObjectDatas(
                result.revertedDatas, model: model)
            return try await data.loadReverted(
                (revertedDatas: idReplacedObjectDatas, info: result.info))
        }
    }

    public func purge() async throws {
        let taskId = await queue.addTask()
        return try await queue.execute(id: taskId) {
            let info = try await sqliteExecutor.purge(model: model)
            await data.loadPurged(info: info)
        }
    }

    public func reset() async throws -> SyncedResultData {
        let taskId = await queue.addTask()
        return try await queue.execute(id: taskId) {
            let ids = await data.changedObjectIdsForReset()
            let objectDatas = try await sqliteExecutor.fetchObjectDatas(
                .init(stableIds: ids), model: model)
            let idReplacedObjectDatas = await loadingIdPool.idReplacedObjectDatas(
                objectDatas, model: model)
            return try await data.loadReset(objectDatas: idReplacedObjectDatas)
        }
    }
}
