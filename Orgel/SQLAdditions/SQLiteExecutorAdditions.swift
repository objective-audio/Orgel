import Foundation

// MARK: - Info

extension SQLiteExecutor {
    public enum FetchInfoError: Error {
        case selectInfoFailed
        case initInfoFailed(OrgelInfo.InitError)
    }

    public func fetchInfo() -> Result<OrgelInfo, FetchInfoError> {
        guard let values = selectSingle(.init(table: OrgelInfo.table)) else {
            return .failure(.selectInfoFailed)
        }

        do {
            let info = try OrgelInfo(values: values)
            return .success(info)
        } catch {
            return .failure(.initInfoFailed(error as! OrgelInfo.InitError))
        }
    }

    public enum UpdateVersionError: Error {
        case updateInfoFailed(SQLiteError)
    }

    public func updateVersion(_ version: Version) -> Result<Void, UpdateVersionError> {
        let result = executeUpdate(
            OrgelInfo.sqlForUpdateVersion,
            parameters: [.version: .text(version.stringValue)])

        switch result {
        case .success:
            return .success(())
        case let .failure(error):
            return .failure(.updateInfoFailed(error))
        }
    }

    public enum CreateInfoError: Error {
        case createInfoTableFailed
        case insertInfoFailed
    }

    public func createInfo(version: Version) -> Result<Void, CreateInfoError> {
        // infoテーブルをデータベース上に作成
        guard case .success(()) = executeUpdate(OrgelInfo.sqlForCreate) else {
            return .failure(.createInfoTableFailed)
        }

        let parameters: [SQLParameter.Name: SQLValue] = [
            .version: .text(version.stringValue),
            .currentSaveId: .integer(0),
            .lastSaveId: .integer(0),
        ]

        // infoデータを挿入。セーブIDは0
        guard
            case .success(()) = executeUpdate(
                OrgelInfo.sqlForInsert, parameters: parameters)
        else {
            return .failure(.insertInfoFailed)
        }

        return .success(())
    }

    public enum UpdateInfoError: Error {
        case updateFailed
        case fetchInfoFailed
    }

    public func updateInfo(currentSaveId: Int64, lastSaveId: Int64) -> Result<
        OrgelInfo, UpdateInfoError
    > {
        guard
            case .success(()) = executeUpdate(
                OrgelInfo.sqlForUpdateSaveIds,
                parameters: [
                    .currentSaveId: .integer(currentSaveId),
                    .lastSaveId: .integer(lastSaveId),
                ])
        else {
            return .failure(.updateFailed)
        }

        guard case let .success(info) = fetchInfo() else {
            return .failure(.fetchInfoFailed)
        }

        return .success(info)
    }

    public enum UpdateCurrentSaveIdError: Error {
        case updateFailed
        case fetchInfoFailed
    }

    public func updateCurrentSaveId(_ currentSaveId: Int64) -> Result<
        OrgelInfo, UpdateCurrentSaveIdError
    > {
        guard
            case .success(()) = executeUpdate(
                OrgelInfo.sqlForUpdateCurrentSaveId,
                parameters: [.currentSaveId: .integer(currentSaveId)])
        else {
            return .failure(.updateFailed)
        }

        guard case let .success(info) = fetchInfo() else {
            return .failure(.fetchInfoFailed)
        }

        return .success(info)
    }
}

// MARK: - Make

extension SQLiteExecutor {
    enum MakeEntityObjectDatasError: Error {
        case sourceObjectIdNotFound
        case selectRelationDataFailed
        case getStableIdFailed
    }

    // 単独のエンティティでオブジェクトのアトリビュートの値を元に関連の値をデータベースから取得してLoadingObjectDataの配列を生成する
    func makeEntityObjectDatas(
        entityName: Entity.Name, modelRelations: [Relation.Name: Relation],
        entityAttributes: [[Attribute.Name: SQLValue]]
    ) -> Result<[LoadingObjectData], Error> {
        var entityDatas: [LoadingObjectData] = []
        entityDatas.reserveCapacity(entityAttributes.count)

        for attributes in entityAttributes {
            var relations: [Relation.Name: [LoadingObjectId]] = [:]

            let saveId = attributes[.saveId]?.integerValue

            // undoしてinsert前に戻すとsaveIdが無い
            if let saveId {
                guard let sourceObjectId = attributes[.objectId]?.integerValue
                else {
                    return .failure(MakeEntityObjectDatasError.sourceObjectIdNotFound)
                }

                guard
                    case let .success(relationIds) = selectRelationIds(
                        modelRelations: modelRelations, saveId: saveId,
                        sourceObjectId: sourceObjectId)
                else {
                    return .failure(MakeEntityObjectDatasError.selectRelationDataFailed)
                }

                relations = relationIds
            }

            do {
                entityDatas.append(
                    try LoadingObjectData(attributes: attributes, relations: relations))
            } catch {
                return .failure(error)
            }
        }

        return .success(entityDatas)
    }
}

// MARK: - Setup

extension SQLiteExecutor {
    public enum MigrateError: Error {
        case fetchInfoFailed
        case updateVersionFailed
        case alterEntityTableFailed
        case createEntityTableFailed
        case createRelationTableFailed
        case createIndexFailed
    }

    public func migrateIfNeeded(model: Model) -> Result<Void, MigrateError> {
        // infoからバージョンを取得。1つしかデータが無いこと前提
        guard case let .success(info) = fetchInfo() else {
            return .failure(.fetchInfoFailed)
        }

        // infoを現在のバージョンで上書き
        guard case .success(()) = updateVersion(model.version) else {
            return .failure(.updateVersionFailed)
        }

        // モデルのバージョンがデータベースのバージョンより低ければマイグレーションを行わない
        if model.version <= info.version {
            return .success(())
        }

        // マイグレーションが必要な場合
        for (entityName, entity) in model.entities {
            if tableExists(entityName.table) {
                // エンティティのテーブルがすでに存在している場合
                for (attributeName, attribute) in entity.allAttributes {
                    if !columnExists(
                        columnName: attributeName.rawValue, tableName: entityName.rawValue)
                    {
                        // テーブルにカラムが存在しなければalter tableを実行する
                        guard
                            case .success(()) = alterTable(
                                entityName.table, column: attribute.column)
                        else {
                            return .failure(.alterEntityTableFailed)
                        }
                    }
                }
            } else {
                // エンティティのテーブルが存在していない場合
                // テーブルを作成する
                guard case .success(()) = executeUpdate(entity.sqlForCreate) else {
                    return .failure(.createEntityTableFailed)
                }
            }

            // 関連のテーブルを作成する
            for (_, relation) in entity.relations {
                guard case .success(()) = executeUpdate(relation.sqlForCreate) else {
                    return .failure(.createRelationTableFailed)
                }
            }
        }

        // インデックスのテーブルを作成する
        for (indexName, index) in model.indices {
            if !indexExists(indexName) {
                guard case .success(()) = executeUpdate(index.sqlForCreate) else {
                    return .failure(.createIndexFailed)
                }
            }
        }

        return .success(())
    }

    public enum CreateInfoAndTablesError: Error {
        case createInfoFailed
        case createEntityTableFailed
        case createRelationTableFailed
        case createIndexFailed
    }

    public func createInfoAndTables(model: Model) -> Result<Void, CreateInfoAndTablesError> {
        // infoテーブルをデータベース上に作成
        guard case .success(()) = createInfo(version: model.version) else {
            return .failure(.createInfoFailed)
        }

        // 全てのエンティティと関連のテーブルをデータベース上に作成する
        for (_, entity) in model.entities {
            guard case .success(()) = executeUpdate(entity.sqlForCreate) else {
                return .failure(.createEntityTableFailed)
            }

            for (_, relation) in entity.relations {
                guard case .success(()) = executeUpdate(relation.sqlForCreate) else {
                    return .failure(.createRelationTableFailed)
                }
            }
        }

        // 全てのインデックスをデータベース上に作成する
        for (_, index) in model.indices {
            guard case .success(()) = executeUpdate(index.sqlForCreate) else {
                return .failure(.createIndexFailed)
            }
        }

        return .success(())
    }

    public enum ClearDBError: Error {
        case deleteEntityTableFailed
        case deleteRelationTableFailed
    }

    public func clearDB(model: Model) -> Result<Void, ClearDBError> {
        for (entityName, entity) in model.entities {
            // エンティティのテーブルのデータを全てデータベースから削除
            guard
                case .success(()) = executeUpdate(
                    .delete(table: entityName.table, where: .none))
            else {
                return .failure(.deleteEntityTableFailed)
            }

            for (_, relation) in entity.relations {
                // 関連のテーブルのデータを全てデータベースから削除
                guard
                    case .success(()) = executeUpdate(
                        .delete(table: relation.table, where: .none))
                else {
                    return .failure(.deleteRelationTableFailed)
                }
            }
        }

        return .success(())
    }
}

// MARK: - Editing

extension SQLiteExecutor {
    enum InsertError: Error {
        case deleteNextToLastFailed
        case insertAttributesFailed
        case selectFailed
        case getStableIdFailed
        case makeObjectDataFailed
    }

    func insert(
        model: Model, info: OrgelInfo, values: [Entity.Name: [[Attribute.Name: SQLValue]]]
    )
        -> Result<[Entity.Name: [LoadingObjectData]], InsertError>
    {
        // lastSaveIdよりcurrentSaveIdが前なら、currentより後のデータは削除する
        if info.currentSaveId < info.lastSaveId {
            guard case .success(()) = deleteNextToLast(model: model, saveId: info.currentSaveId)
            else {
                return .failure(.deleteNextToLastFailed)
            }
        }

        var insertedDatas: [Entity.Name: [LoadingObjectData]] = [:]
        let nextSaveId = info.nextSaveId

        for (entityName, entityValues) in values {
            // エンティティのデータ中のオブジェクトIDの最大値から次のIDを取得する
            // まだデータがなければ初期値の1のまま
            let max =
                max(table: entityName.table, columnName: .objectId)
                .integerValue ?? 0
            let startObjectId = max + 1

            for (index, objectValues) in entityValues.enumerated() {
                // オブジェクトの値を与えてデータベースに挿入する
                let objectIdValue = SQLValue.integer(startObjectId + Int64(index))
                var columnNames: [SQLColumn.Name] = [.objectId, .saveId]
                var parameters: [SQLParameter.Name: SQLValue] = [
                    .objectId: objectIdValue,
                    .saveId: .integer(nextSaveId),
                ]

                columnNames.reserveCapacity(columnNames.count + objectValues.count)
                parameters.reserveCapacity(parameters.count + objectValues.count)

                for (attributeName, value) in objectValues {
                    let columnName = attributeName.columnName
                    columnNames.append(columnName)
                    parameters[columnName.defaultParameterName] = value
                }

                guard
                    case .success(()) = executeUpdate(
                        .insert(table: entityName.table, columnNames: columnNames),
                        parameters: parameters)
                else {
                    return .failure(.insertAttributesFailed)
                }

                // 挿入したオブジェクトのattributeをデータベースから取得する
                let select = SQLSelect(
                    table: entityName.table,
                    where: .expression(
                        .compare(
                            .objectId, .equal, .name(.objectId))),
                    parameters: [.objectId: objectIdValue])

                guard case let .success(selectResult) = self.select(select),
                    !selectResult.isEmpty
                else {
                    return .failure(.selectFailed)
                }

                // データをobjectDataにしてcompletionに返すinsertedDatasに追加
                if insertedDatas[entityName] == nil {
                    insertedDatas[entityName] = []
                }

                let attributes = selectResult[0]

                do {
                    insertedDatas[entityName]!.append(
                        try LoadingObjectData(attributes: .init(attributes), relations: [:]))
                } catch {
                    return .failure(.makeObjectDataFailed)
                }
            }
        }

        return .success(insertedDatas)
    }

    enum FetchError: Error {
        case fetchInfoFailed
        case getRelationsFailed
        case selectLastFailed
        case makeEntityObjectDatasFailed
    }

    func loadObjectDatas(model: Model, option: FetchOption) -> Result<
        [Entity.Name: [LoadingObjectData]], FetchError
    > {
        // カレントセーブIDをデータベースから取得
        guard case let .success(info) = fetchInfo() else {
            return .failure(.fetchInfoFailed)
        }

        let currentSaveId = info.currentSaveId

        var loadedDatas: [Entity.Name: [LoadingObjectData]] = [:]

        for (entityTable, select) in option.selects {
            let entityName = Entity.Name(table: entityTable)

            guard let modelRelations = model.entities[entityName]?.relations else {
                return .failure(.getRelationsFailed)
            }

            // カレントセーブIDまでで条件にあった最後のデータをデータベースから取得する
            guard
                case let .success(entityAttributes) = selectLast(
                    select, saveId: currentSaveId, includeRemoved: false)
            else {
                return .failure(.selectLastFailed)
            }

            // アトリビュートのみのデータから関連のデータを加えてobject_dataを生成する
            guard
                case let .success(objectDatas) = makeEntityObjectDatas(
                    entityName: entityName, modelRelations: modelRelations,
                    entityAttributes: .init(entityAttributes))
            else {
                return .failure(.makeEntityObjectDatasFailed)
            }

            loadedDatas[entityName] = objectDatas
        }

        return .success(loadedDatas)
    }

    enum SaveError: Error {
        case deleteFailed
        case getEntityFailed
        case getStableIdFailed
        case maxFailed
        case insertAttributesFailed
        case getRelationsFailed
        case getSavedEntityDatasFailed
        case getPkIdFailed
        case getModelRelationFailed
        case convertRelationIdFailed
        case relationIdsOverflow
        case insertRelationsFailed
    }

    func save(
        model: Model, info: OrgelInfo, changedDatas: [Entity.Name: [SavingObjectData]]
    )
        -> Result<[Entity.Name: [LoadingObjectData]], SaveError>
    {
        // lastSaveIdよりcurrentSaveIdが前なら、currentより後のデータは削除する
        if info.currentSaveId < info.lastSaveId {
            guard case .success(()) = deleteNextToLast(model: model, saveId: info.currentSaveId)
            else {
                return .failure(.deleteFailed)
            }
        }

        var savedDatas: [Entity.Name: [LoadingObjectData]] = [:]
        var temporaryIdToStableId: [TemporaryId: StableId] = [:]

        for (entityName, changedEntityDatas) in changedDatas {
            guard let entity = model.entities[entityName] else {
                return .failure(.getEntityFailed)
            }

            let entityInsertSql = entity.sqlForInsert

            var entitySavedDatas: [LoadingObjectData] = []

            for changedData in changedEntityDatas {
                var attributes = changedData.attributes

                // 不要な値が含まれていないことをチェック
                precondition(attributes[.pkId] == nil)
                precondition(attributes[.saveId] == nil)
                precondition(attributes[.objectId] == nil)
                precondition(attributes[.action] == nil)

                attributes[.action] = changedData.action.sqlValue

                // 保存するデータのセーブIDを今セーブするIDにセットする
                attributes[.saveId] = info.nextSaveIdValue

                if let stableId = changedData.id.stable {
                    // 保存するデータにstableIdがあればそのままセット
                    attributes[.objectId] = .integer(stableId.rawValue)
                } else {
                    // 保存するデータにまだstableIdがなければ（挿入されてtemporaryな状態）データベース上の最大値+1をセットする
                    let objectId =
                        max(table: entityName.table, columnName: .objectId)
                        .integerValue
                        ?? 0
                    attributes[.objectId] = .integer(objectId + 1)
                }

                // データベースにアトリビュートのデータを挿入する
                guard
                    case .success(()) = executeUpdate(
                        entityInsertSql, parameters: .init(attributes))
                else {
                    return .failure(.insertAttributesFailed)
                }

                // 挿入したデータのrowidを取得
                let pkId = lastInsertRowId

                attributes[.pkId] = .integer(pkId)

                guard
                    let stableId = attributes[.objectId]?
                        .integerValue
                else {
                    return .failure(.getStableIdFailed)
                }

                entitySavedDatas.append(
                    .init(
                        id: .init(stable: .init(stableId), temporary: changedData.id.temporary),
                        attributes: attributes, relations: [:]))

                if let temporaryId = changedData.id.temporary {
                    temporaryIdToStableId[temporaryId] = .init(stableId)
                }
            }

            savedDatas[entityName] = entitySavedDatas
        }

        for (entityName, changedEntityDatas) in changedDatas {
            guard let modelRelations = model.entities[entityName]?.relations else {
                return .failure(.getRelationsFailed)
            }

            guard let savedEntityDatas = savedDatas[entityName] else {
                return .failure(.getSavedEntityDatasFailed)
            }

            for (index, changedData) in changedEntityDatas.enumerated() {
                var savedData = savedEntityDatas[index]

                guard let sourcePkId = savedData.values?.pkId else {
                    return .failure(.getPkIdFailed)
                }

                let sourceStableId = savedData.id.stable

                for (relationName, relation) in changedData.relations {
                    guard let modelRelation = modelRelations[relationName] else {
                        return .failure(.getModelRelationFailed)
                    }

                    let relationIds: [StableId]

                    do {
                        relationIds = try relation.map {
                            if let stableId = $0.stable {
                                return stableId
                            } else if let temporaryId = $0.temporary,
                                let stableId = temporaryIdToStableId[temporaryId]
                            {
                                return stableId
                            } else {
                                throw SaveError.convertRelationIdFailed
                            }
                        }
                    } catch {
                        return .failure(.convertRelationIdFailed)
                    }

                    if !modelRelation.many && relationIds.count > 1 {
                        return .failure(.relationIdsOverflow)
                    }

                    let relationTargetObjectIds = relationIds.compactMap {
                        let value = $0.sqlValue
                        return value.isNull ? nil : value
                    }

                    guard
                        case .success(()) = insertRelations(
                            relation: modelRelation, sourcePkId: .integer(sourcePkId),
                            sourceObjectId: .integer(sourceStableId.rawValue),
                            relationTargetObjectIds: relationTargetObjectIds,
                            saveId: info.nextSaveIdValue)
                    else {
                        return .failure(.insertRelationsFailed)
                    }

                    // pkIdの取得時にvaluesが存在していることは確定している
                    savedData.updateRelations(
                        relationIds.map(LoadingObjectId.stable), forName: relationName)
                }

                savedDatas.setObjectData(savedData, entityName: entityName, index: index)
            }
        }

        return .success(savedDatas)
    }

    enum RemoveRelationsAtSaveError: Error {
        case entityNotFound
        case objectIdNotFound
        case relationNotFound
        case selectRelationRemovedFailed
        case objectStableIdNotFound
        case objectStableIdDuplicated
        case makeEntityObjectDatasFailed
        case inverseEntityNotFound
        case insertAttributesFailed
        case modelRelationNotFound
        case insertRelationsFailed
    }

    func removeRelationsAtSave(
        model: Model, info: OrgelInfo, changedDatas: [Entity.Name: [SavingObjectData]]
    ) -> Result<Void, RemoveRelationsAtSaveError> {
        // オブジェクトが削除された場合に逆関連があったらデータベース上で関連を外す
        let nextSaveIdValue = info.nextSaveIdValue

        for (entityName, changedEntityDatas) in changedDatas {
            // エンティティごとの処理
            guard let inverseRelationNames = model.entities[entityName]?.inverseRelationNames else {
                return .failure(.entityNotFound)
            }

            guard !inverseRelationNames.isEmpty else {
                continue
            }

            // 削除されたobject_idを取得
            var targetObjectIds: Set<StableId> = .init()
            targetObjectIds.reserveCapacity(changedEntityDatas.count)

            for objectData in changedEntityDatas {
                guard objectData.action == .remove else {
                    // 削除されていなければスキップ
                    continue
                }
                guard let stableId = objectData.id.stable else {
                    return .failure(.objectIdNotFound)
                }
                targetObjectIds.insert(stableId)
            }

            guard !targetObjectIds.isEmpty else {
                // 削除されたオブジェクトがなければスキップ
                continue
            }

            for (inverseEntityName, relationNames) in inverseRelationNames {
                var entityAttributes: [Int64: [Attribute.Name: SQLValue]] = [:]

                // tgt_obj_idsが関連先に含まれているオブジェクトのアトリビュートを取得
                for relationName in relationNames {
                    guard let relation = model.entities[inverseEntityName]?.relations[relationName]
                    else {
                        return .failure(.relationNotFound)
                    }

                    guard
                        case let .success(selectedValues) = selectForSave(
                            entityName: inverseEntityName, relationTable: relation.table,
                            targetObjectIds: targetObjectIds)
                    else {
                        return .failure(.selectRelationRemovedFailed)
                    }

                    for attributes in selectedValues {
                        guard let stableId = attributes[.objectId]?.integerValue else {
                            return .failure(.objectStableIdNotFound)
                        }

                        guard entityAttributes[stableId] == nil else {
                            return .failure(.objectStableIdDuplicated)
                        }

                        entityAttributes[stableId] = attributes
                    }
                }

                guard !entityAttributes.isEmpty else {
                    continue
                }

                guard let inverseEntity = model.entities[inverseEntityName] else {
                    return .failure(.inverseEntityNotFound)
                }

                let modelRelations = inverseEntity.relations

                // アトリビュートを元に関連を取得する

                guard
                    case let .success(inverseRemovedDatas) = makeEntityObjectDatas(
                        entityName: inverseEntityName, modelRelations: modelRelations,
                        entityAttributes: entityAttributes.map { $0.value })
                else {
                    return .failure(.makeEntityObjectDatasFailed)
                }

                guard !inverseRemovedDatas.isEmpty else {
                    continue
                }

                let entityInsertSql = inverseEntity.sqlForInsert

                for objectData in inverseRemovedDatas {
                    var attributes = objectData.attributes

                    // 保存するデータのpkIdは無い（rowidなのでいらない）
                    precondition(attributes[.pkId] == nil)

                    // 保存するデータのセーブIDを今セーブするIDにする
                    attributes[.saveId] = nextSaveIdValue

                    let stableId = objectData.id.stable
                    let sourceObjectId = SQLValue.integer(stableId.rawValue)
                    attributes[.objectId] = sourceObjectId

                    attributes[.action] = objectData.values?.action.sqlValue

                    // データベースにアトリビュートのデータを挿入する
                    guard
                        case .success(()) = executeUpdate(
                            entityInsertSql, parameters: .init(attributes))
                    else {
                        return .failure(.insertAttributesFailed)
                    }

                    // pk_idを取得してセットする
                    let sourcePkId = SQLValue.integer(lastInsertRowId)

                    for (relationName, relation) in objectData.relations {
                        // データベースに関連のデータを挿入する
                        guard let modelRelation = modelRelations[relationName] else {
                            return .failure(.modelRelationNotFound)
                        }

                        let relationTargetObjectIds = relation.filter { objectId in
                            return !targetObjectIds.contains(objectId.stable)
                        }.map(\.stable)

                        if !relationTargetObjectIds.isEmpty {
                            guard
                                case .success(()) = insertRelations(
                                    relation: modelRelation, sourcePkId: sourcePkId,
                                    sourceObjectId: sourceObjectId,
                                    relationTargetObjectIds: .init(relationTargetObjectIds),
                                    saveId: nextSaveIdValue)
                            else {
                                return .failure(.insertRelationsFailed)
                            }
                        }
                    }
                }
            }
        }

        return .success(())
    }

    enum DeleteNextToLastError: Error {
        case deleteEntityFailed
        case deleteRelationFailed
    }

    // 指定したsave_idより大きいsave_idのデータを、全てのエンティティに対してデータベース上から削除する
    func deleteNextToLast(model: Model, saveId: Int64) -> Result<
        Void, DeleteNextToLastError
    > {
        let deleteExprs = SQLWhere.expression(
            .compare(.saveId, .greaterThan, .name(.saveId)))
        let parameters: [SQLParameter.Name: SQLValue] = [.saveId: .integer(saveId)]

        for (entityName, entity) in model.entities {
            guard
                case .success(()) = executeUpdate(
                    .delete(table: entityName.table, where: deleteExprs),
                    parameters: parameters)
            else {
                return .failure(.deleteEntityFailed)
            }

            for (_, relation) in entity.relations {
                guard
                    case .success(()) = executeUpdate(
                        .delete(table: relation.table, where: deleteExprs),
                        parameters: parameters)
                else {
                    return .failure(.deleteRelationFailed)
                }
            }
        }

        return .success(())
    }

    enum InsertRelationsError: Error {
        case insertRelationFailed
    }

    func insertRelations(
        relation: Relation, sourcePkId: SQLValue, sourceObjectId: SQLValue,
        relationTargetObjectIds: [SQLValue], saveId: SQLValue
    ) -> Result<Void, InsertRelationsError> {
        let sql = relation.sqlForInsert

        for relationTargetObjectId in relationTargetObjectIds {
            let parameters: [SQLParameter.Name: SQLValue] = [
                .sourcePkId: sourcePkId,
                .sourceObjectId: sourceObjectId,
                .targetObjectId: relationTargetObjectId,
                .saveId: saveId,
            ]

            guard case .success(()) = executeUpdate(sql, parameters: parameters) else {
                return .failure(.insertRelationFailed)
            }
        }

        return .success(())
    }

    enum PurgeError: Error {
        case fetchInfoFailed
        case deleteNextToLastFailed
        case purgeAttributesFailed
        case updateEntitySaveIdFailed
        case purgeRelationsFailed
        case updateRelationSaveIdFailed
    }

    func purgeAll(model: Model) -> Result<Void, PurgeError> {
        // DB情報をデータベースから取得
        guard case let .success(info) = fetchInfo() else {
            return .failure(.fetchInfoFailed)
        }

        if info.currentSaveId < info.lastSaveId {
            // ラストよりカレントのセーブIDが小さければ、カレントより大きいセーブIDのデータを削除
            // つまり、アンドゥした分を削除
            guard case .success(()) = deleteNextToLast(model: model, saveId: info.currentSaveId)
            else {
                return .failure(.deleteNextToLastFailed)
            }
        }

        let saveIdColumnNames: [SQLColumn.Name] = [.saveId]
        let oneValueParameters: [SQLParameter.Name: SQLValue] = [.saveId: .integer(1)]

        for (entityName, entity) in model.entities {
            // エンティティのデータをパージする（同じオブジェクトIDのデータは最後のものだけ生かす）
            guard case .success(()) = purgeAttributes(entityName: entityName) else {
                return .failure(.purgeAttributesFailed)
            }

            // 残ったデータのセーブIDを全て1にする
            let updateEntitySql = SQLUpdate.update(
                table: entityName.table, columnNames: saveIdColumnNames)

            guard
                case .success(()) = executeUpdate(
                    updateEntitySql, parameters: oneValueParameters)
            else {
                return .failure(.updateEntitySaveIdFailed)
            }

            for (_, relation) in entity.relations {
                let relationTable = relation.table

                // 関連のデータをパージする（同じソースIDのデータは最後のものだけ生かす）
                guard
                    case .success(()) = purgeRelations(
                        table: relationTable, sourceEntityName: entityName)
                else {
                    return .failure(.purgeRelationsFailed)
                }

                // 残ったデータのセーブIDを全て1にする
                let updateRelationSql = SQLUpdate.update(
                    table: relationTable, columnNames: saveIdColumnNames)
                guard
                    case .success(()) = executeUpdate(
                        updateRelationSql, parameters: oneValueParameters)
                else {
                    return .failure(.updateRelationSaveIdFailed)
                }
            }
        }

        return .success(())
    }

    private func purgeAttributes(entityName: Entity.Name) -> UpdateResult {
        let inExpr = SQLWhere.expression(
            .in(
                field: .not(.pkId),
                source: .select(
                    .init(
                        table: entityName.table, field: .max(.pkId),
                        groupBy: [.objectId]))))
        return executeUpdate(
            .delete(table: entityName.table, where: inExpr))
    }

    private func purgeRelations(table: SQLTable, sourceEntityName: Entity.Name) -> UpdateResult {
        let select = SQLSelect(table: sourceEntityName.table, field: .column(.pkId))
        let inExpr = SQLWhere.expression(
            .in(field: .not(.sourcePkId), source: .select(select)))
        return executeUpdate(
            .delete(table: table, where: inExpr))
    }
}

// MARK: - Select

extension SQLiteExecutor {
    public func select(_ select: SQLSelect) -> Result<[[SQLColumn.Name: SQLValue]], QueryError> {
        let queryResult = executeQuery(
            .select(select), parameters: select.parameters,
            iteration: { iterator in
                var selectResult: [[SQLColumn.Name: SQLValue]] = []

                while iterator.next() {
                    selectResult.append(iterator.values)
                }

                return selectResult
            })

        switch queryResult {
        case let .success(value):
            return .success(value)
        case let .failure(error):
            return .failure(error)
        }
    }

    public func selectSingle(_ select: SQLSelect) -> [SQLColumn.Name: SQLValue]? {
        var select = select
        select.limitRange = .init(location: 0, length: 1)

        switch self.select(select) {
        case let .success(values):
            return values.first
        case .failure:
            return nil
        }
    }

    enum SelectForUndoError: Error {
        case invalidSaveId
        case selectFailed
        case selectEmptyFailed
    }

    func selectForUndo(entityName: Entity.Name, revertSaveId: Int64, currentSaveId: Int64)
        -> Result<
            [[Attribute.Name:
                SQLValue]], SelectForUndoError
        >
    {
        // リバート先のセーブIDはカレントより小さくないといけない
        guard revertSaveId < currentSaveId else {
            return .failure(.invalidSaveId)
        }

        // アンドゥで戻そうとしているデータ（リバート先からカレントまでの間）のobjectIdの集合を取得する
        let revertingWhere = SQLWhere.and([
            .expression(.compare(.saveId, .lessThanOrEqual, .value(.integer(currentSaveId)))),
            .expression(.compare(.saveId, .greaterThan, .value(.integer(revertSaveId)))),
        ])
        let revertingSelect = SQLSelect(
            table: entityName.table, field: .column(.objectId),
            where: revertingWhere,
            distinct: true)
        // 戻そうとしているobjectIdと一致し、リバート時点より前のデータの中で最後のもののrowidの集合を取得する
        // つまり、アンドゥ時点より前に挿入されて、アンドゥ時点より後に変更があったデータを取得する
        let revertedLastWhere = SQLWhere.and([
            .expression(.in(field: .column(.objectId), source: .select(revertingSelect))),
            .expression(.compare(.saveId, .lessThanOrEqual, .value(.integer(revertSaveId)))),
        ])
        let revertedLastSelect = SQLSelect(
            table: entityName.table, field: .max(.rowid),
            where: revertedLastWhere,
            groupBy: [.objectId])
        let select = SQLSelect(
            table: entityName.table,
            where: .expression(.in(field: .column(.rowid), source: .select(revertedLastSelect))),
            columnOrders: [.init(name: .objectId, order: .ascending)])

        guard case let .success(selectResult) = self.select(select) else {
            return .failure(.selectFailed)
        }

        // アンドゥで戻そうとしている範囲のデータの中で、insertのobjectIdの集合をobjectIdのみで取得
        // つまり、アンドゥ時点より後に挿入されたデータを空にするために取得する
        let emptySelect = SQLSelect(
            table: entityName.table, field: .column(.objectId),
            where: .and([
                .expression(.compare(.saveId, .lessThanOrEqual, .value(.integer(currentSaveId)))),
                .expression(.compare(.saveId, .greaterThan, .value(.integer(revertSaveId)))),
                .expression(.compare(.action, .equal, .name(.action))),
            ]),
            parameters: [.action: .insertAction],
            columnOrders: [.init(name: .objectId, order: .ascending)])

        guard case let .success(emptyResult) = self.select(emptySelect) else {
            return .failure(.selectEmptyFailed)
        }

        // キャッシュを上書きするためのデータを返す
        return .success(.init(selectResult + emptyResult))
    }

    enum SelectForRedoError: Error {
        case invalidSaveId
        case selectLastFailed(QueryError)
    }

    func selectForRedo(entityName: Entity.Name, revertSaveId: Int64, currentSaveId: Int64)
        -> Result<
            [[Attribute.Name:
                SQLValue]], SelectForRedoError
        >
    {
        // リバート先のセーブIDはカレントより後でないといけない
        guard currentSaveId < revertSaveId else {
            return .failure(.invalidSaveId)
        }

        // カレントからリドゥ時点の範囲で変更のあったデータを取得して返す
        let option = SQLSelect(
            table: entityName.table,
            where: .expression(.compare(.saveId, .greaterThan, .value(.integer(currentSaveId)))),
            columnOrders: [.init(name: .objectId, order: .ascending)])

        switch selectLast(option, saveId: revertSaveId, includeRemoved: true) {
        case let .success(values):
            return .success(.init(values))
        case let .failure(error):
            return .failure(.selectLastFailed(error))
        }
    }

    enum SelectForRevertError: Error {
        case selectForUndoFailed(SelectForUndoError)
        case selectForRedoFailed(SelectForRedoError)
    }

    func selectForRevert(entityName: Entity.Name, revertSaveId: Int64, currentSaveId: Int64)
        -> Result<
            [[Attribute.Name:
                SQLValue]], SelectForRevertError
        >
    {
        // リバート先のセーブIDによってアンドゥとリドゥに分岐する
        if revertSaveId < currentSaveId {
            switch selectForUndo(
                entityName: entityName, revertSaveId: revertSaveId, currentSaveId: currentSaveId)
            {
            case let .success(values):
                return .success(values)
            case let .failure(error):
                return .failure(.selectForUndoFailed(error))
            }
        } else if currentSaveId < revertSaveId {
            switch selectForRedo(
                entityName: entityName, revertSaveId: revertSaveId, currentSaveId: currentSaveId)
            {
            case let .success(value):
                return .success(value)
            case let .failure(error):
                return .failure(.selectForRedoFailed(error))
            }
        } else {
            return .success([])
        }
    }

    enum SelectForSaveError: Error {
        case selectFailed(QueryError)
    }

    func selectForSave(
        entityName: Entity.Name, relationTable: SQLTable, targetObjectIds: Set<StableId>
    ) -> Result<[[Attribute.Name: SQLValue]], SelectForSaveError> {
        // 最後のオブジェクトのpk_idを取得するsql
        let lastSelect = SQLSelect(
            table: entityName.table, field: .column(.pkId),
            where: .last(
                table: entityName.table, where: .none, lastSaveId: nil, includeRemoved: false))

        // 最後のオブジェクトの中でtgt_obj_idsに一致する関連のsrc_pk_idを取得するsql
        let targetExpressions = SQLWhere.and([
            .expression(.in(field: .column(.sourcePkId), source: .select(lastSelect))),
            .expression(.in(field: .column(.targetObjectId), source: .ids(targetObjectIds))),
        ])

        let sourcePkSelect = SQLSelect(
            table: relationTable, field: .column(.sourcePkId),
            where: targetExpressions
        )

        // これまでの条件に一致しつつ、アクションがremoveでないアトリビュートを取得する
        let expressions = SQLWhere.and([
            .expression(.compare(.action, .notEqual, .name(.action))),
            .expression(.in(field: .column(.pkId), source: .select(sourcePkSelect))),
        ])
        let option = SQLSelect(
            table: entityName.table, where: expressions,
            parameters: [.action: .removeAction])

        switch select(option) {
        case let .success(values):
            return .success(.init(values))
        case let .failure(error):
            return .failure(.selectFailed(error))
        }
    }

    public func selectLast(_ select: SQLSelect, saveId: Int64, includeRemoved: Bool) -> Result<
        [[SQLColumn.Name: SQLValue]], QueryError
    > {
        var select = select
        select.where =
            .last(
                table: select.table,
                where: select.where,
                lastSaveId: saveId,
                includeRemoved: includeRemoved
            )
        return self.select(select)
    }

    public func max(table: SQLTable, columnName: SQLColumn.Name) -> SQLValue {
        let queryResult = executeQuery(
            .select(.init(table: table, field: .max(columnName))),
            iteration: { iterator in
                guard iterator.next() else { return SQLValue.null }
                return iterator.columnValue(forIndex: 0)
            })

        switch queryResult {
        case let .success(value):
            return value
        case .failure:
            return .null
        }
    }
}

// MARK: - Private

extension SQLiteExecutor {
    // 単独のオブジェクトの全ての関連の関連先のidの配列をDBから取得する
    private enum SelectRelationIdsError: Error {
        case selectRelationTargetIdsFailed
    }

    private func selectRelationIds(
        modelRelations: [Relation.Name: Relation], saveId: Int64, sourceObjectId: Int64
    ) -> Result<[Relation.Name: [LoadingObjectId]], SelectRelationIdsError> {
        var relations: [Relation.Name: [LoadingObjectId]] = [:]

        for (relationName, modelRelation) in modelRelations {
            let relationTable = modelRelation.table

            guard
                case let .success(relationIds) = selectRelationTargetIds(
                    relationTable: relationTable, saveId: saveId, sourceObjectId: sourceObjectId)
            else {
                return .failure(.selectRelationTargetIdsFailed)
            }

            relations[relationName] = relationIds
        }

        return .success(relations)
    }

    // 単独の関連の関連先のidの配列をDBから取得する
    private enum SelectRelationTargetIdsError: Error {
        case selectFailed
        case targetObjectIdNotFound
    }

    private func selectRelationTargetIds(
        relationTable: SQLTable, saveId: Int64, sourceObjectId: Int64
    ) -> Result<[LoadingObjectId], SelectRelationTargetIdsError> {
        let expressions = SQLWhere.and([
            .expression(.compare(.saveId, .equal, .name(.saveId))),
            .expression(
                .compare(
                    .sourceObjectId, .equal, .name(.sourceObjectId)
                )),
        ])

        let select = SQLSelect(
            table: relationTable, where: expressions,
            parameters: [
                .saveId: .integer(saveId),
                .sourceObjectId: .integer(sourceObjectId),
            ])

        guard case let .success(relations) = self.select(select) else {
            return .failure(.selectFailed)
        }

        var relationTargetIds: [LoadingObjectId] = []

        for relation in relations {
            guard let stableId = relation[.targetObjectId]?.integerValue else {
                return .failure(.targetObjectIdNotFound)
            }

            relationTargetIds.append(.stable(.init(stableId)))
        }

        return .success(relationTargetIds)
    }
}

// MARK: -

extension [Entity.Name: [LoadingObjectData]] {
    mutating fileprivate func setObjectData(
        _ objectData: LoadingObjectData, entityName: Entity.Name, index: Int
    ) {
        self[entityName]?[index] = objectData
    }
}

extension [Attribute.Name: SQLValue] {
    init(_ source: [SQLColumn.Name: SQLValue]) {
        self = source.reduce(
            into: .init(),
            { partialResult, pair in
                partialResult[.init(pair.key.sqlStringValue)] = pair.value
            })
    }
}

extension [[Attribute.Name: SQLValue]] {
    init(_ source: [[SQLColumn.Name: SQLValue]]) {
        self = source.map { .init($0) }
    }
}

extension [SQLParameter.Name: SQLValue] {
    init(_ source: [Attribute.Name: SQLValue]) {
        self = source.reduce(
            into: .init(),
            { partialResult, pair in
                partialResult[pair.key.columnName.defaultParameterName] = pair.value
            })
    }
}

extension [[SQLParameter.Name: SQLValue]] {
    init(_ source: [[Attribute.Name: SQLValue]]) {
        self = source.map { .init($0) }
    }
}
