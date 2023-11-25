import Combine
import Foundation

@MainActor
public final class SyncedObject {
    public typealias Status = SyncedObjectStatus

    private struct Values {
        var attributes: [Attribute.Name: SQLValue]
        var relationIds: [Relation.Name: [ObjectId]]
    }

    public internal(set) var entity: Entity
    private var rawData: RawSyncedObjectData?
    public var attributes: [Attribute.Name: SQLValue] { rawData?.attributes ?? [:] }
    public var relationIds: [Relation.Name: [ObjectId]] { rawData?.relationIds ?? [:] }

    private var syncedId: SyncedObjectId
    public var id: ObjectId { syncedId.objectId }

    public var saveId: Int64? { rawData?.saveId }
    public var action: ObjectAction? { rawData?.action }
    public var isAvailable: Bool { rawData?.isAvailable ?? false }

    private lazy var fetcher: Fetcher<ObjectEvent> = {
        .init { [weak self] in
            guard let self else { return nil }
            return .fetched(object: self)
        }
    }()

    public var publisher: AnyPublisher<ObjectEvent, Never> {
        fetcher.eraseToAnyPublisher()
    }

    private var cancellableForDatabase: AnyCancellable?

    init(entity: Entity) {
        self.entity = entity
        syncedId = .init()
        rawData = nil
    }

    public var status: Status { rawData.status }

    public func setAttributeValue(_ value: SQLValue, forName name: Attribute.Name) {
        precondition(validateAttributeName(name))

        if let prevAttribute = attributes[name], prevAttribute == value {
            return
        }

        guard isAvailable else {
            return
        }

        rawData?.attributes[name] = value

        didChange()

        sendObjectEvent(.attributeUpdated(object: self, name: name, value: value))
    }

    public func setRelationObjects(_ objects: [SyncedObject], forName name: Relation.Name) {
        setRelationIds(objects.map(\.id), forName: name)
    }

    public func addRelationObject(_ object: SyncedObject, forName name: Relation.Name) {
        addRelationId(object.id, forName: name)
    }

    public func insertRelationObject(
        _ object: SyncedObject, forName name: Relation.Name, at index: Int
    ) {
        insertRelationId(object.id, forName: name, at: index)
    }

    public func removeRelationObject(_ object: SyncedObject, forName name: Relation.Name) {
        removeRelationId(object.id, forName: name)
    }

    public func removeRelation(forName name: Relation.Name, at index: Int) {
        removeRelations(forName: name, indexSet: [index])
    }

    public func removeRelations(forName name: Relation.Name, indexSet: IndexSet) {
        precondition(entity.relations[name] != nil)

        guard var ids = relationIds[name] else { return }

        let prevIdsCount = ids.count

        for index in indexSet.reversed() where index < ids.count {
            ids.remove(at: index)
        }

        guard prevIdsCount != ids.count else {
            return
        }

        rawData?.relationIds[name] = ids

        didChange()

        sendObjectEvent(.relationRemoved(object: self, name: name, indices: .init(indexSet)))
    }

    public func removeAllRelations(forName name: Relation.Name) {
        precondition(entity.relations[name] != nil)

        guard let ids = relationIds[name] else { return }

        rawData?.relationIds[name] = nil

        didChange()

        let indices = (0..<ids.count).map { $0 }

        sendObjectEvent(.relationRemoved(object: self, name: name, indices: indices))
    }

    public func remove() {
        guard isAvailable else {
            return
        }

        rawData?.remove()

        sendObjectEvent(.removed(object: self))
    }

    public func attributeValue(forName name: Attribute.Name) -> SQLValue {
        precondition(validateAttributeName(name))

        return attributes[name] ?? .null
    }

    public func relationIds(forName name: Relation.Name) -> [ObjectId] {
        precondition(validateRelationName(name))

        return relationIds[name] ?? []
    }

    public var relationStableIds: [Entity.Name: Set<StableId>] {
        var result: [Entity.Name: Set<StableId>] = [:]

        for (entityName, modelRelation) in entity.relations {
            let relationIds = relationIds(forName: entityName)
            guard !relationIds.isEmpty else { continue }

            if result[modelRelation.target] == nil {
                result[modelRelation.target] = .init()
            }

            for relationId in relationIds {
                if let stableId = relationId.stable {
                    result[modelRelation.target]?.insert(stableId)
                }
            }
        }

        return result
    }

    private enum TypedError: Error {
        case removed
    }

    public func typed<T: ObjectCodable>(_ type: T.Type) throws -> T {
        if action == .remove {
            throw TypedError.removed
        } else {
            try ObjectDecoder().decode(type, from: objectDataForSave(), entity: entity)
        }
    }

    private enum UpdateError: Error {
        case idMismatch
    }

    public func updateByTyped<T: ObjectCodable>(_ typed: T) throws {
        guard typed.id.rawId == id else {
            throw UpdateError.idMismatch
        }

        let objectData = try ObjectEncoder().encode(typed, entity: entity)

        for (name, value) in objectData.attributes {
            setAttributeValue(value, forName: name)
        }

        for (name, ids) in objectData.relations {
            setRelationIds(ids, forName: name)
        }
    }
}

// MARK: - Internal

extension SyncedObject {
    func setRelationIds(_ ids: [ObjectId], forName name: Relation.Name) {
        precondition(validateRelationName(name))
        precondition(validateRelationIds(ids))

        guard isAvailable else {
            return
        }

        if let prevRelation = relationIds[name], prevRelation == ids {
            return
        }

        rawData?.relationIds[name] = ids

        didChange()

        sendObjectEvent(.relationReplaced(object: self, name: name))
    }

    func addRelationId(_ relationId: ObjectId, forName name: Relation.Name) {
        if let prevRelation = relationIds[name] {
            insertRelationId(relationId, forName: name, at: prevRelation.count)
        } else {
            insertRelationId(relationId, forName: name, at: 0)
        }
    }

    func insertRelationId(
        _ relationId: ObjectId, forName name: Relation.Name, at index: Int
    ) {
        precondition(entity.relations[name] != nil)
        precondition(validateRelationId(relationId))

        guard isAvailable else { return }

        if relationIds[name] == nil {
            rawData?.relationIds[name] = []
        }

        rawData?.relationIds[name]!.insert(relationId, at: index)

        didChange()

        sendObjectEvent(.relationInserted(object: self, name: name, indices: [index]))
    }

    func removeRelationId(_ relationId: ObjectId, forName name: Relation.Name) {
        precondition(entity.relations[name] != nil)
        precondition(validateRelationId(relationId))

        guard action != .remove else { return }
        guard let ids = relationIds[name] else { return }

        var remainedIds: [ObjectId] = []
        var removedIndices: [Int] = []

        for index in 0..<ids.count {
            let objectId = ids[index]
            if objectId == relationId {
                removedIndices.append(index)
            } else {
                remainedIds.append(objectId)
            }
        }

        guard !removedIndices.isEmpty else {
            return
        }

        rawData?.relationIds[name] = remainedIds

        didChange()

        sendObjectEvent(.relationRemoved(object: self, name: name, indices: removedIndices))
    }

    func objectDataForSave() throws -> SavingObjectData {
        enum ObjectDataForSaveError: Error {
            case actionNotFound
        }

        guard let action else {
            throw ObjectDataForSaveError.actionNotFound
        }

        let resultAttributes: [Attribute.Name: SQLValue] = entity.customAttributes.reduce(
            into: .init()
        ) {
            partialResult, pair in
            let name = pair.key
            let attribute = pair.value

            if let value = attributes[name] {
                partialResult[name] = value
            } else if attribute.notNull {
                partialResult[name] = attribute.defaultValue
            } else {
                partialResult[name] = .null
            }
        }

        let resultRelations: [Relation.Name: [ObjectId]] = entity.relations.reduce(
            into: .init()
        ) {
            (partialResult, pair) in
            let name = pair.key

            guard let ids = relationIds[name] else { return }

            partialResult[name] = ids
        }

        return .init(
            id: id, action: action, attributes: resultAttributes, relations: resultRelations)
    }

    func loadInsertionData() {
        precondition(!syncedId.hasValue && rawData == nil)

        syncedId.setNewTemporary()

        rawData = .available(
            .init(
                state: .created(.init(updating: .created)),
                attributes: entity.defaultCustomAttributeValues,
                relationIds: [:]))
    }

    /// LoadingObjectDataのデータを読み込んで上書きする
    /// force == falseなら、データベースへの保存処理を始めた後でもオブジェクトに変更があったら上書きしない
    /// force == trueなら、必ず上書きする
    func loadData(_ data: LoadingObjectData, force: Bool) {
        assert(validateId(data.id))

        syncedId.replaceId(data.id)

        if let dataValues = data.values {
            if dataValues.action == .remove {
                rawData = .unavailable(
                    .init(state: .removed(.init(saveId: dataValues.saveId, updating: .saved))))
            } else if action == .remove, status == .changed, !force {
                rawData = .unavailable(
                    .init(state: .removed(.init(saveId: dataValues.saveId, updating: .changed)))
                )
            } else {
                struct ChangedValues {
                    let attributes: [Attribute.Name: SQLValue]
                    let relationIds: [Relation.Name: [ObjectId]]
                }

                let changedValues: ChangedValues? =
                    if status == .changed, !force, let rawData {
                        .init(
                            attributes: rawData.attributes, relationIds: rawData.relationIds)
                    } else {
                        nil
                    }

                let savedState: RawSyncedObjectData.Available.State.Saved.State

                switch dataValues.action {
                case .insert:
                    savedState = .inserted
                case .update:
                    savedState = .updated
                case .remove:
                    fatalError()
                }

                let relationIds: [Relation.Name: [ObjectId]] = dataValues.relations.reduce(
                    into: .init(),
                    { partialResult, pair in
                        partialResult[pair.key] = pair.value.map(ObjectId.init)
                    })

                rawData = .available(
                    .init(
                        state: .saved(
                            .init(
                                state: savedState, saveId: dataValues.saveId,
                                updating: changedValues != nil ? .changed : .saved)),
                        attributes: changedValues?.attributes ?? dataValues.attributes,
                        relationIds: changedValues?.relationIds ?? relationIds))
            }

            sendObjectEvent(.loaded(object: self))
        } else {
            rawData = nil
            sendObjectEvent(.cleared(object: self))
        }
    }

    // purgeされたときに全て1にするために呼ばれる
    func loadSaveId(_ loadingSaveId: SQLValue) {
        guard let saveId = loadingSaveId.integerValue else { return }
        rawData?.setSaveId(saveId)
    }

    func clearData() {
        guard rawData != nil else { return }

        rawData = nil

        sendObjectEvent(.cleared(object: self))
    }

    func setStatusToSaving() {
        rawData?.setStatusToSaving()
    }

    func observeForDatabase(_ handler: @escaping (ObjectEvent) -> Void) {
        cancellableForDatabase = fetcher.sink(receiveValue: handler)
    }
}

// MARK: - Private

extension SyncedObject {
    private func didChange() {
        precondition(action != .remove)
        guard status != .created else { return }
        rawData?.didChange()
    }

    private func validateId(_ otherId: LoadingObjectId) -> Bool {
        guard syncedId.hasValue else {
            return true
        }

        if status != .cleared, let lhsTemporary = syncedId.temporary,
            let rhsTemporary = otherId.temporary,
            lhsTemporary != rhsTemporary
        {
            return false
        } else if let lhsStable = syncedId.stable, lhsStable != otherId.stable {
            return false
        } else {
            return true
        }
    }

    private func sendObjectEvent(_ event: ObjectEvent) {
        let fetcher = fetcher

        if Thread.isMainThread {
            fetcher.send(event)
        } else {
            DispatchQueue.main.async {
                fetcher.send(event)
            }
        }
    }

    private func validateAttributeName(_ name: Attribute.Name) -> Bool {
        entity.customAttributes[name] != nil
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
