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
        return try await queue.execute {
            let result = try await self.sqliteExecutor.insertObjects(
                model: self.model, values: values)
            return try await self.data.loadInserted(result)
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
        return try await queue.execute {
            let objectDatas = try await self.sqliteExecutor.fetchObjectDatas(
                option, model: self.model)
            let idReplacedObjectDatas = await self.loadingIdPool.idReplacedObjectDatas(
                objectDatas, model: self.model)
            return try await self.data.loadFetched(objectDatas: idReplacedObjectDatas)
        }
    }

    public func fetchReadOnlyObjects(_ option: FetchOption) async throws -> ReadOnlyResultData {
        return try await queue.execute {
            let objectDatas = try await self.sqliteExecutor.fetchObjectDatas(
                option, model: self.model)
            let idReplacedObjectDatas = await self.loadingIdPool.idReplacedObjectDatas(
                objectDatas, model: self.model)
            return try self.makeReadOnlyObjects(objectDatas: idReplacedObjectDatas)
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
        return try await queue.execute {
            let info = try await self.sqliteExecutor.clear(model: self.model)
            await self.loadingIdPool.clear()
            await self.data.loadCleared(info: info)
        }
    }

    public func save() async throws -> SyncedResultData {
        return try await queue.execute {
            let changedDatas = try await self.data.changedObjectDatasForSave()
            let result = try await self.sqliteExecutor.save(
                model: self.model, changedDatas: changedDatas)
            await self.loadingIdPool.set(from: result.savedDatas)
            return try await self.data.loadSaved(result)
        }
    }

    public func revert(saveId: Int64) async throws -> SyncedResultData {
        return try await queue.execute {
            let result = try await self.sqliteExecutor.revert(
                model: self.model, revertSaveId: saveId)
            let idReplacedObjectDatas = await self.loadingIdPool.idReplacedObjectDatas(
                result.revertedDatas, model: self.model)
            return try await self.data.loadReverted(
                (revertedDatas: idReplacedObjectDatas, info: result.info))
        }
    }

    public func purge() async throws {
        return try await queue.execute {
            let info = try await self.sqliteExecutor.purge(model: self.model)
            await self.data.loadPurged(info: info)
        }
    }

    public func reset() async throws -> SyncedResultData {
        return try await queue.execute {
            let ids = await self.data.changedObjectIdsForReset()
            let objectDatas = try await self.sqliteExecutor.fetchObjectDatas(
                .init(stableIds: ids), model: self.model)
            let idReplacedObjectDatas = await self.loadingIdPool.idReplacedObjectDatas(
                objectDatas, model: self.model)
            return try await self.data.loadReset(objectDatas: idReplacedObjectDatas)
        }
    }
}
