import Combine
import Foundation

@MainActor
public final class OrgelData {
    let infoSubject: CurrentValueSubject<OrgelInfo, Never>
    public var info: OrgelInfo { infoSubject.value }
    public var infoPublisher: AnyPublisher<OrgelInfo, Never> {
        infoSubject.eraseToAnyPublisher()
    }

    let objectSubject: PassthroughSubject<SyncedObject, Never> = .init()
    public var objectPublisher: AnyPublisher<SyncedObject, Never> {
        objectSubject.eraseToAnyPublisher()
    }

    private(set) var createdObjects: [Entity.Name: [TemporaryId: SyncedObject]] = [:]
    private(set) var cachedObjects: [Entity.Name: [StableId: Weak<SyncedObject>]] = [:]
    private(set) var changedObjects: [Entity.Name: [StableId: SyncedObject]] = [:]

    private let model: Model

    init(info: OrgelInfo, model: Model) {
        infoSubject = .init(info)
        self.model = model
    }
}

extension OrgelData {
    public var hasCreatedObjects: Bool {
        createdObjects.contains { !$0.value.isEmpty }
    }

    public var hasChangedObjects: Bool {
        changedObjects.contains { !$0.value.isEmpty }
    }

    public func createdObjectCount(entityName: Entity.Name) -> Int {
        createdObjects[entityName]?.count ?? 0
    }

    public func changedObjectCount(entityName: Entity.Name) -> Int {
        changedObjects[entityName]?.count ?? 0
    }

    public func createObject<T: ObjectCodable>(_ type: T.Type) throws -> T {
        let object = createObject(entityName: type.entityName)
        return try object.typed(T.self)
    }

    public func cachedOrCreatedObject<T: ObjectCodable>(_ type: T.Type, id: T.Id) throws -> T? {
        try cachedOrCreatedObject(entityName: type.entityName, objectId: id.rawId)?.typed(type)
    }

    /// データベースに保存せず仮にオブジェクトを生成する
    /// この時点ではobjectIdやsaveIdは振られていない
    public func createObject(entityName: Entity.Name) -> SyncedObject {
        let object = makeObject(entityName: entityName)

        object.loadInsertionData()

        if let temporaryId = object.id.temporary {
            if createdObjects[entityName] == nil {
                createdObjects[entityName] = [:]
            }
            createdObjects[entityName]?[temporaryId] = object
        } else {
            assertionFailure()
        }

        return object
    }

    // キャッシュされた単独のオブジェクトをエンティティ名とオブジェクトIDを指定して取得する
    public func cachedOrCreatedObject(entityName: Entity.Name, objectId: ObjectId)
        -> SyncedObject?
    {
        if let temporaryId = objectId.temporary,
            let created = createdObjects[entityName]?[temporaryId]
        {
            created
        } else if let stableId = objectId.stable,
            let cached = cachedObjects[entityName]?[stableId]?.value
        {
            cached
        } else {
            nil
        }
    }

    public func relationObjects(sourceObject: SyncedObject, relationName: Relation.Name)
        -> [SyncedObject?]
    {
        let relationIds = sourceObject.relationIds(forName: relationName)

        guard let targetEntityName = sourceObject.entity.relations[relationName]?.target else {
            return []
        }

        return relationIds.map {
            cachedOrCreatedObject(entityName: targetEntityName, objectId: $0)
        }
    }

    public func relationObject(
        sourceObject: SyncedObject, relationName: Relation.Name, at index: Int
    ) -> SyncedObject? {
        guard let targetEntityName = sourceObject.entity.relations[relationName]?.target else {
            return nil
        }

        let relationIds = sourceObject.relationIds(forName: relationName)

        guard index < relationIds.count else { return nil }

        return cachedOrCreatedObject(
            entityName: targetEntityName, objectId: relationIds[index])
    }

    /// データベースに保存するために、全てのエンティティで変更のあったオブジェクトのobjectDataを取得する
    func changedObjectDatasForSave() throws -> [Entity.Name: [SavingObjectData]] {
        enum ChangedObjectDatasError: Error {
            case attributesIsEmpty
        }

        var changedDatas: [Entity.Name: [SavingObjectData]] = [:]

        for (entityName, _) in model.entities {
            // 仮に挿入されたオブジェクトの数
            let insertedCount = createdObjects[entityName]?.count ?? 0
            // 値に変更のあったオブジェクトの数
            let changedCount = changedObjects[entityName]?.count ?? 0
            // 挿入か変更のあったオブジェクトの数の合計
            let totalCount = insertedCount + changedCount

            // 挿入も変更もされていなければスキップ
            guard totalCount > 0 else {
                continue
            }

            var entityDatas: [SavingObjectData] = []
            entityDatas.reserveCapacity(totalCount)

            if let entityObjects = createdObjects[entityName] {
                // 挿入されたオブジェクトからデータベース用のデータを取得

                for (_, object) in entityObjects {
                    let objectData = try object.objectDataForSave()

                    guard !objectData.attributes.isEmpty else {
                        throw ChangedObjectDatasError.attributesIsEmpty
                    }

                    entityDatas.append(objectData)
                }
            }

            if let entityObjects = changedObjects[entityName] {
                // 変更されたオブジェクトからデータベース用のデータを取得

                for (_, object) in entityObjects {
                    let objectData = try object.objectDataForSave()

                    guard !objectData.attributes.isEmpty else {
                        throw ChangedObjectDatasError.attributesIsEmpty
                    }

                    entityDatas.append(objectData)

                    object.setStatusToSaving()
                }
            }

            changedDatas[entityName] = entityDatas
        }

        return changedDatas
    }

    // リセットするために、全てのエンティティで変更のあったオブジェクトのobject_idを取得する
    func changedObjectIdsForReset() -> [Entity.Name: Set<StableId>] {
        var changedObjectIds: [Entity.Name: Set<StableId>] = [:]

        for (entityName, entityObjects) in changedObjects {
            var entityIds: Set<StableId> = .init()

            for (id, _) in entityObjects {
                entityIds.insert(id)
            }

            if !entityIds.isEmpty {
                changedObjectIds[entityName] = entityIds
            }
        }

        return changedObjectIds
    }
}

extension OrgelData {
    /// managerで管理するobjectを作成する。キャッシュへの追加は別途行う
    func makeObject(entityName: Entity.Name) -> SyncedObject {
        guard let entity = model.entities[entityName] else { fatalError() }

        let object = SyncedObject(entity: entity)

        object.observeForDatabase { [weak self] event in
            guard let self else { return }

            if let changedObject = event.changedObject {
                self.objectDidChange(changedObject)
            }
        }

        return object
    }

    // object_datasに含まれるオブジェクトIDと一致するものはchangedObjectsから取り除く
    // データベースに保存された後などに呼ばれる。
    func eraseChangedObjects(inObjectDatas: [Entity.Name: [LoadingObjectData]]) {
        for (entityName, entityObjectDatas) in inObjectDatas {
            for objectData in entityObjectDatas {
                let stableId = objectData.id.stable
                changedObjects[entityName]?[stableId] = nil
            }

            if changedObjects[entityName]?.count == 0 {
                changedObjects[entityName] = nil
            }
        }
    }

    func cachedObject(entityName: Entity.Name, stableId: StableId) -> SyncedObject? {
        cachedObjects[entityName]?[stableId]?.value
    }

    func makeCachedObject(entityName: Entity.Name, stableId: StableId) -> SyncedObject {
        if cachedObjects[entityName] == nil {
            cachedObjects[entityName] = [:]
        }

        let object = makeObject(entityName: entityName)

        cachedObjects[entityName]?[stableId] = .init(value: object)

        return object
    }
}

extension OrgelData {
    func loadInserted(_ result: SQLiteExecutor.InsertObjectsResult) throws
        -> SyncedResultData
    {
        infoSubject.value = result.info

        return try loadAndCacheObjects(
            objectDatas: result.insertedDatas, force: false, isSave: false)
    }

    func loadCleared(info: OrgelInfo) {
        infoSubject.value = info

        // キャッシュされている全てのオブジェクトをクリアする
        createdObjects.enumerate { _, temporaryId, object in
            object.clearData()
        }
        cachedObjects.enumerate { _, _, object in
            object.clearData()
        }
        cachedObjects.removeAll()
        createdObjects.removeAll()
        changedObjects.removeAll()
    }

    func loadSaved(_ result: SQLiteExecutor.SaveResult) throws -> SyncedResultData {
        infoSubject.value = result.info

        let resultData = try loadAndCacheObjects(
            objectDatas: result.savedDatas, force: false, isSave: true)

        eraseChangedObjects(inObjectDatas: result.savedDatas)

        return resultData
    }

    func loadReverted(_ result: SQLiteExecutor.RevertResult) throws -> SyncedResultData {
        infoSubject.value = result.info

        return try loadAndCacheObjects(
            objectDatas: result.revertedDatas, force: false, isSave: false)
    }

    func loadPurged(info: OrgelInfo) {
        infoSubject.value = info

        // キャッシュされている全てのオブジェクトをパージする（save_idを全て1にする）

        let oneValue = SQLValue.integer(1)

        // キャッシュされたオブジェクトのセーブIDを全て1にする
        cachedObjects.enumerate { _, objectId, object in
            object.loadSaveId(oneValue)
        }
    }

    func loadReset(objectDatas: [Entity.Name: [LoadingObjectData]]) throws
        -> SyncedResultData
    {
        var resultData = try loadAndCacheObjects(
            objectDatas: objectDatas, force: true, isSave: false)

        eraseChangedObjects(inObjectDatas: objectDatas)

        for (entityName, objects) in createdObjects {
            if resultData[entityName] == nil {
                resultData[entityName] = .init(order: [], objects: [:])
            }

            for (_, object) in objects {
                resultData[entityName]!.order.append(object.id)
                resultData[entityName]!.objects[object.id] = object
            }
        }

        createdObjects.enumerate { _, _, object in
            object.clearData()
        }
        createdObjects.removeAll()

        return resultData
    }

    func loadFetched(objectDatas: [Entity.Name: [LoadingObjectData]]) throws
        -> SyncedResultData
    {
        try loadAndCacheObjects(objectDatas: objectDatas, force: false, isSave: false)
    }
}

extension OrgelData {
    private func loadAndCacheObject(
        entityName: Entity.Name, objectData: LoadingObjectData, force: Bool, isSave: Bool
    ) throws -> SyncedObject {
        let stableId = objectData.id.stable

        // セーブ時で仮に挿入されたオブジェクトがある場合にオブジェクトを取得
        if isSave, let entityObjects = createdObjects[entityName], !entityObjects.isEmpty,
            let temporaryId = objectData.id.temporary, let object = entityObjects[temporaryId]
        {
            createdObjects[entityName]?[temporaryId] = nil

            cachedObjects.setObject(object, stableId: stableId, entityName: entityName)
            createdObjects.removeEntityIfEmpty(name: entityName)

            object.loadData(objectData, force: force)

            return object
        }

        // 挿入でなければobjectはnullなので、キャッシュから取得、または追加する
        let object: SyncedObject =
            if let cachedObject = cachedObject(entityName: entityName, stableId: stableId) {
                cachedObject
            } else {
                makeCachedObject(entityName: entityName, stableId: stableId)
            }

        object.loadData(objectData, force: force)

        if !object.isAvailable {
            cachedObjects[entityName]?[objectData.id.stable] = nil
        }

        return object
    }

    func loadAndCacheObjects(
        objectDatas: [Entity.Name: [LoadingObjectData]], force: Bool, isSave: Bool
    ) throws -> SyncedResultData {
        enum LoadAndCacheObjectsArrayError: Error {
            case getStableIdFailed
        }

        var resultData: [Entity.Name: SyncedEntityResultData] = [:]

        for (entityName, entityDatas) in objectDatas {
            var entityOrder: [ObjectId] = []
            var entityObjects: [ObjectId: SyncedObject] = [:]
            entityOrder.reserveCapacity(entityDatas.count)
            entityObjects.reserveCapacity(entityDatas.count)

            for objectData in entityDatas {
                let object = try loadAndCacheObject(
                    entityName: entityName, objectData: objectData, force: force, isSave: isSave)
                entityOrder.append(objectData.id.objectId)
                entityObjects[objectData.id.objectId] = object
            }

            createdObjects[entityName] = nil

            resultData[entityName] = .init(order: entityOrder, objects: entityObjects)
        }

        return resultData
    }
}

extension OrgelData {
    private func objectDidChange(_ object: SyncedObject) {
        let entityName = object.entity.name

        if object.status == .created {
            // 仮に生成された状態の場合
            if createdObjects[entityName] != nil, object.action == .remove {
                if let temporaryId = object.id.temporary {
                    // オブジェクトが削除されていたら、createdObjectsからも削除
                    createdObjects[entityName]?[temporaryId] = nil
                } else {
                    assertionFailure()
                }
            }
        } else {
            // 挿入されたのではない場合
            // changedObjectsにオブジェクトを追加
            if let stableId = object.id.stable {
                var objects = changedObjects[entityName] ?? [:]
                if objects[stableId] == nil {
                    objects[stableId] = object
                    changedObjects[entityName] = objects
                }
            } else {
                assertionFailure()
            }
        }

        if object.action == .remove {
            // オブジェクトが削除されていたら逆関連も削除する
            if let entity = model.entities[entityName] {
                for (invEntityName, invRelNames) in entity.inverseRelationNames {
                    createdObjects.enumerateEntity(name: invEntityName) {
                        entityName, temporaryId, invRelObject in
                        for invRelName in invRelNames {
                            invRelObject.removeRelationId(object.id, forName: invRelName)
                        }
                    }
                    cachedObjects.enumerateEntity(name: invEntityName) {
                        entityName, objectId, invRelObject in
                        for invRelName in invRelNames {
                            invRelObject.removeRelationId(object.id, forName: invRelName)
                        }
                    }
                }
            } else {
                assertionFailure()
            }
        }

        // オブジェクトが変更された通知を送信
        objectSubject.send(object)
    }
}
