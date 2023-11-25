import Combine
import Foundation
import OrderedCollections
import Orgel

@MainActor
final class Interactor {
    enum Event {
        case operationFailed(Error)
    }

    private let container: OrgelContainer

    var info: OrgelInfo { container.data.info }
    var infoPublisher: AnyPublisher<OrgelInfo, Never> {
        container.data.infoPublisher
    }

    private let objectsSubject:
        CurrentValueSubject<[Entity.Name: OrderedDictionary<ObjectId, SyncedObject>], Never> =
            .init(
                [:])
    var objects: [Entity.Name: OrderedDictionary<ObjectId, SyncedObject>] {
        get { objectsSubject.value }
        set { objectsSubject.value = newValue }
    }
    var objectsPublisher:
        AnyPublisher<[Entity.Name: OrderedDictionary<ObjectId, SyncedObject>], Never>
    {
        objectsSubject.eraseToAnyPublisher()
    }

    private let eventSubject: PassthroughSubject<Event, Never> = .init()
    var eventPublisher: AnyPublisher<Event, Never> { eventSubject.eraseToAnyPublisher() }

    private let processingCountSubject: CurrentValueSubject<Int, Never> = .init(0)
    var isProcessing: Bool {
        processingCountSubject.value > 0
    }
    var isProcessingPublisher: AnyPublisher<Bool, Never> {
        processingCountSubject.map { $0 > 0 }.eraseToAnyPublisher()
    }

    private var cancellables: Set<AnyCancellable> = []

    init(databaseContainer: OrgelContainer) {
        self.container = databaseContainer

        databaseContainer.data.objectPublisher.sink { [weak self] object in
            guard let self else { return }

            #warning("todo 消したい?")
            if !object.isAvailable {
                self.objects[object.entity.name]?[object.id] = nil
            }

            self.objects = self.objects
        }.store(in: &cancellables)

        Task {
            beginProcessing()
            defer { endProcessing() }

            try await fetchAndReplaceObjects()
        }
    }

    func createObject(entityName: Entity.Name) {
        guard !isProcessing else {
            return
        }

        let object = container.data.createObject(entityName: entityName)

        objects.insert(object, entityName: entityName)
    }

    func insert(entityName: Entity.Name) {
        enum InsertError: Error {
            case objectNotFound
        }

        guard !isProcessing, canInsert else {
            return
        }

        Task {
            beginProcessing()
            defer { endProcessing() }

            do {
                _ = try await container.executor.save()

                let insertedObjects =
                    try await container.executor.insertSyncedObjects(values: [
                        entityName: [[.name: .text(UUID().uuidString)]]
                    ])

                guard let insertedObject = insertedObjects[entityName]?.objects.first?.value else {
                    throw InsertError.objectNotFound
                }

                objects.insert(insertedObject, entityName: entityName)
            } catch {
                eventSubject.send(.operationFailed(error))
            }
        }
    }

    func remove(entityName: Entity.Name, indexSet: IndexSet) {
        guard !isProcessing, let entityObjects = objects[entityName] else {
            return
        }

        for index in indexSet.reversed() {
            entityObjects.elements[index].value.remove()
        }
    }

    func undo() {
        guard !isProcessing, canUndo else {
            return
        }

        let undoId = currentSaveId - 1

        Task {
            beginProcessing()
            defer { endProcessing() }

            do {
                let resetResultData = try await container.executor.reset()
                objects.update(by: resetResultData)
                let revertResultData = try await container.executor.revert(saveId: undoId)
                objects.update(by: revertResultData)
            } catch {
                eventSubject.send(.operationFailed(error))
            }
        }
    }

    func redo() {
        guard !isProcessing, canRedo else {
            return
        }

        let redoId = currentSaveId + 1

        Task {
            beginProcessing()
            defer { endProcessing() }

            do {
                let resetResultData = try await container.executor.reset()
                objects.update(by: resetResultData)
                let revertResultData = try await container.executor.revert(saveId: redoId)
                objects.update(by: revertResultData)
            } catch {
                eventSubject.send(.operationFailed(error))
            }
        }
    }

    func clear() {
        guard !isProcessing, canClear else {
            return
        }

        Task {
            beginProcessing()
            defer { endProcessing() }

            do {
                try await container.executor.clear()
                try await fetchAndReplaceObjects()
            } catch {
                eventSubject.send(.operationFailed(error))
            }
        }
    }

    func purge() {
        guard !isProcessing, canPurge else {
            return
        }

        Task {
            beginProcessing()
            defer { endProcessing() }

            do {
                let savedResultData = try await container.executor.save()
                objects.update(by: savedResultData)
                try await container.executor.purge()
                try await fetchAndReplaceObjects()
            } catch {
                eventSubject.send(.operationFailed(error))
            }
        }
    }

    func saveChanged() {
        guard !isProcessing, hasChanged else {
            return
        }

        Task {
            beginProcessing()
            defer { endProcessing() }

            do {
                let savedResultData = try await container.executor.save()
                objects.update(by: savedResultData)
            } catch {
                eventSubject.send(.operationFailed(error))
            }
        }
    }

    func cancelChanged() {
        guard !isProcessing, hasChanged else {
            return
        }

        Task {
            beginProcessing()
            defer { endProcessing() }

            do {
                let resetResultData = try await container.executor.reset()
                objects.update(by: resetResultData)
            } catch {
                eventSubject.send(.operationFailed(error))
            }
        }
    }

    var canInsert: Bool {
        !hasChanged
    }

    var canUndo: Bool {
        !hasChanged && currentSaveId > 0
    }

    var canRedo: Bool {
        !hasChanged && currentSaveId < lastSaveId
    }

    var canClear: Bool {
        lastSaveId > 0
    }

    var canPurge: Bool {
        !hasChanged && lastSaveId > 1
    }

    var hasChanged: Bool {
        container.data.hasChangedObjects || container.data.hasCreatedObjects
    }

    func object(entityName: Entity.Name, at index: Int) -> SyncedObject? {
        objects[entityName]?.elements[index].value
    }

    func object(entityName: Entity.Name, id: ObjectId) -> SyncedObject? {
        objects[entityName]?[id]
    }

    func objectCount(entityName: Entity.Name) -> Int {
        objects[entityName]?.count ?? 0
    }

    func relationObject(sourceObject: SyncedObject, relationName: Relation.Name, at index: Int)
        -> SyncedObject?
    {
        container.data.relationObject(
            sourceObject: sourceObject, relationName: relationName, at: index)
    }

    var currentSaveId: Int64 {
        container.data.info.currentSaveId
    }

    var lastSaveId: Int64 {
        container.data.info.lastSaveId
    }
}

extension Interactor {
    private func fetchAndReplaceObjects() async throws {
        objects = try await fetchObjects()
    }

    nonisolated private func fetchObjects() async throws -> [Entity.Name: OrderedDictionary<
        ObjectId, SyncedObject
    >] {
        let selects = container.model.entities.keys.map {
            SQLSelect(table: $0.table, columnOrders: [.init(name: .objectId, order: .ascending)])
        }

        let fetchedData = try await container.executor.fetchSyncedObjects(.init(selects: selects))

        return fetchedData.reduce(into: .init()) { partialResult, pair in
            var dictionary = OrderedDictionary<ObjectId, SyncedObject>(
                uncheckedUniqueKeysWithValues: pair.value.objects)
            dictionary.sort()
            partialResult[pair.key] = dictionary
        }
    }

    private func beginProcessing() {
        processingCountSubject.value += 1
    }

    private func endProcessing() {
        processingCountSubject.value -= 1
    }
}

extension [Entity.Name: OrderedDictionary<ObjectId, SyncedObject>] {
    fileprivate mutating func sortAll() {
        self[.a]?.sort()
        self[.b]?.sort()
    }

    @MainActor
    fileprivate mutating func update(by resultData: SyncedResultData) {
        for (entityName, entityData) in resultData {
            var entityObjects = self[entityName] ?? .init()
            for (id, object) in entityData.objects {
                // 単にbothのidをセットしても置き換わらないので必ず一旦削除する
                entityObjects[id] = nil
                if object.isAvailable {
                    entityObjects[id] = object
                }
            }
            entityObjects.sort()
            self[entityName] = entityObjects
        }
    }

    @MainActor
    fileprivate mutating func insert(
        _ object: SyncedObject, entityName: Entity.Name
    ) {
        var entityObjects = self[entityName] ?? .init()
        entityObjects.insertAndSort(object)
        self[entityName] = entityObjects
    }
}

extension OrderedDictionary<ObjectId, SyncedObject> {
    @MainActor
    fileprivate mutating func insertAndSort(_ object: SyncedObject) {
        self[object.id] = object
        sort()
    }
}
