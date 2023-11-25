import Foundation

// MARK: - Info

extension SQLiteExecutor {
    public func fetchInfo() throws -> OrgelInfo {
        enum FetchInfoError: Error {
            case selectInfoFailed
        }

        guard let values = selectSingle(.init(table: OrgelInfo.table)) else {
            throw FetchInfoError.selectInfoFailed
        }

        return try OrgelInfo(values: values)
    }

    public func updateVersion(_ version: Version) throws {
        try executeUpdate(
            OrgelInfo.sqlForUpdateVersion,
            parameters: [.version: .text(version.stringValue)])
    }

    public func createInfo(version: Version) throws {
        // infoテーブルをデータベース上に作成
        try executeUpdate(OrgelInfo.sqlForCreate)

        let parameters: [SQLParameter.Name: SQLValue] = [
            .version: .text(version.stringValue),
            .currentSaveId: .integer(0),
            .lastSaveId: .integer(0),
        ]

        // infoデータを挿入。セーブIDは0
        try executeUpdate(OrgelInfo.sqlForInsert, parameters: parameters)
    }

    public func updateInfo(currentSaveId: Int64, lastSaveId: Int64) throws -> OrgelInfo {
        try executeUpdate(
            OrgelInfo.sqlForUpdateSaveIds,
            parameters: [
                .currentSaveId: .integer(currentSaveId),
                .lastSaveId: .integer(lastSaveId),
            ])

        return try fetchInfo()
    }

    public func updateCurrentSaveId(_ currentSaveId: Int64) throws -> OrgelInfo {
        try executeUpdate(
            OrgelInfo.sqlForUpdateCurrentSaveId,
            parameters: [.currentSaveId: .integer(currentSaveId)])

        return try fetchInfo()
    }
}

// MARK: - Make

extension SQLiteExecutor {
    // 単独のエンティティでオブジェクトのアトリビュートの値を元に関連の値をデータベースから取得してLoadingObjectDataの配列を生成する
    func makeEntityObjectDatas(
        entityName: Entity.Name, modelRelations: [Relation.Name: Relation],
        entityAttributes: [[Attribute.Name: SQLValue]]
    ) throws -> [LoadingObjectData] {
        enum MakeEntityObjectDatasError: Error {
            case sourceObjectIdNotFound
            case selectRelationDataFailed
        }

        var entityDatas: [LoadingObjectData] = []
        entityDatas.reserveCapacity(entityAttributes.count)

        for attributes in entityAttributes {
            var relations: [Relation.Name: [LoadingObjectId]] = [:]

            let saveId = attributes[.saveId]?.integerValue

            // undoしてinsert前に戻すとsaveIdが無い
            if let saveId {
                guard let sourceObjectId = attributes[.objectId]?.integerValue
                else {
                    throw MakeEntityObjectDatasError.sourceObjectIdNotFound
                }

                guard
                    let relationIds = try? selectRelationIds(
                        modelRelations: modelRelations, saveId: saveId,
                        sourceObjectId: sourceObjectId)
                else {
                    throw MakeEntityObjectDatasError.selectRelationDataFailed
                }

                relations = relationIds
            }

            entityDatas.append(
                try LoadingObjectData(attributes: attributes, relations: relations))
        }

        return entityDatas
    }
}

// MARK: - Setup

extension SQLiteExecutor {
    public func migrateIfNeeded(model: Model) throws {
        // infoからバージョンを取得。1つしかデータが無いこと前提
        let info: OrgelInfo = try fetchInfo()

        // infoを現在のバージョンで上書き
        try updateVersion(model.version)

        // モデルのバージョンがデータベースのバージョンより低ければマイグレーションを行わない
        if model.version <= info.version {
            return
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
                        try alterTable(entityName.table, column: attribute.column)
                    }
                }
            } else {
                // エンティティのテーブルが存在していない場合
                // テーブルを作成する
                try executeUpdate(entity.sqlForCreate)
            }

            // 関連のテーブルを作成する
            for (_, relation) in entity.relations {
                try executeUpdate(relation.sqlForCreate)
            }
        }

        // インデックスのテーブルを作成する
        for (indexName, index) in model.indices {
            if !indexExists(indexName) {
                try executeUpdate(index.sqlForCreate)
            }
        }
    }

    public func createInfoAndTables(model: Model) throws {
        // infoテーブルをデータベース上に作成
        try createInfo(version: model.version)

        // 全てのエンティティと関連のテーブルをデータベース上に作成する
        for (_, entity) in model.entities {
            try executeUpdate(entity.sqlForCreate)

            for (_, relation) in entity.relations {
                try executeUpdate(relation.sqlForCreate)
            }
        }

        // 全てのインデックスをデータベース上に作成する
        for (_, index) in model.indices {
            try executeUpdate(index.sqlForCreate)
        }
    }

    public func clearDB(model: Model) throws {
        for (entityName, entity) in model.entities {
            // エンティティのテーブルのデータを全てデータベースから削除
            try executeUpdate(.delete(table: entityName.table, where: .none))

            for (_, relation) in entity.relations {
                // 関連のテーブルのデータを全てデータベースから削除
                try executeUpdate(
                    .delete(table: relation.table, where: .none))
            }
        }
    }
}

// MARK: - Editing

extension SQLiteExecutor {
    func insert(
        model: Model, info: OrgelInfo, values: [Entity.Name: [[Attribute.Name: SQLValue]]]
    )
        throws -> [Entity.Name: [LoadingObjectData]]
    {
        enum InsertError: Error {
            case selectFailed
        }

        // lastSaveIdよりcurrentSaveIdが前なら、currentより後のデータは削除する
        if info.currentSaveId < info.lastSaveId {
            try deleteNextToLast(model: model, saveId: info.currentSaveId)
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

                try executeUpdate(
                    .insert(table: entityName.table, columnNames: columnNames),
                    parameters: parameters)

                // 挿入したオブジェクトのattributeをデータベースから取得する
                let select = SQLSelect(
                    table: entityName.table,
                    where: .expression(
                        .compare(
                            .objectId, .equal, .name(.objectId))),
                    parameters: [.objectId: objectIdValue])

                let selectResult = try self.select(select)
                guard !selectResult.isEmpty else {
                    throw InsertError.selectFailed
                }

                // データをobjectDataにしてcompletionに返すinsertedDatasに追加
                if insertedDatas[entityName] == nil {
                    insertedDatas[entityName] = []
                }

                let attributes = selectResult[0]

                insertedDatas[entityName]!.append(
                    try LoadingObjectData(attributes: .init(attributes), relations: [:]))
            }
        }

        return insertedDatas
    }

    func loadObjectDatas(model: Model, option: FetchOption) throws -> [Entity.Name:
        [LoadingObjectData]]
    {
        enum FetchError: Error {
            case getRelationsFailed
        }

        // カレントセーブIDをデータベースから取得
        let info = try fetchInfo()

        let currentSaveId = info.currentSaveId

        var loadedDatas: [Entity.Name: [LoadingObjectData]] = [:]

        for (entityTable, select) in option.selects {
            let entityName = Entity.Name(table: entityTable)

            guard let modelRelations = model.entities[entityName]?.relations else {
                throw FetchError.getRelationsFailed
            }

            // カレントセーブIDまでで条件にあった最後のデータをデータベースから取得する
            let entityAttributes = try selectLast(
                select, saveId: currentSaveId, includeRemoved: false)

            // アトリビュートのみのデータから関連のデータを加えてobject_dataを生成する
            let objectDatas = try makeEntityObjectDatas(
                entityName: entityName, modelRelations: modelRelations,
                entityAttributes: .init(entityAttributes))

            loadedDatas[entityName] = objectDatas
        }

        return loadedDatas
    }

    func save(
        model: Model, info: OrgelInfo, changedDatas: [Entity.Name: [SavingObjectData]]
    ) throws -> [Entity.Name: [LoadingObjectData]] {
        enum SaveError: Error {
            case getEntityFailed
            case getStableIdFailed
            case getRelationsFailed
            case getSavedEntityDatasFailed
            case getPkIdFailed
            case getModelRelationFailed
            case convertRelationIdFailed
            case relationIdsOverflow
        }

        // lastSaveIdよりcurrentSaveIdが前なら、currentより後のデータは削除する
        if info.currentSaveId < info.lastSaveId {
            try deleteNextToLast(model: model, saveId: info.currentSaveId)
        }

        var savedDatas: [Entity.Name: [LoadingObjectData]] = [:]
        var temporaryIdToStableId: [TemporaryId: StableId] = [:]

        for (entityName, changedEntityDatas) in changedDatas {
            guard let entity = model.entities[entityName] else {
                throw SaveError.getEntityFailed
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
                try executeUpdate(
                    entityInsertSql, parameters: .init(attributes))

                // 挿入したデータのrowidを取得
                let pkId = lastInsertRowId

                attributes[.pkId] = .integer(pkId)

                guard
                    let stableId = attributes[.objectId]?
                        .integerValue
                else {
                    throw SaveError.getStableIdFailed
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
                throw SaveError.getRelationsFailed
            }

            guard let savedEntityDatas = savedDatas[entityName] else {
                throw SaveError.getSavedEntityDatasFailed
            }

            for (index, changedData) in changedEntityDatas.enumerated() {
                var savedData = savedEntityDatas[index]

                guard let sourcePkId = savedData.values?.pkId else {
                    throw SaveError.getPkIdFailed
                }

                let sourceStableId = savedData.id.stable

                for (relationName, relation) in changedData.relations {
                    guard let modelRelation = modelRelations[relationName] else {
                        throw SaveError.getModelRelationFailed
                    }

                    let relationIds: [StableId] = try relation.map {
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

                    if !modelRelation.many && relationIds.count > 1 {
                        throw SaveError.relationIdsOverflow
                    }

                    let relationTargetObjectIds = relationIds.compactMap {
                        let value = $0.sqlValue
                        return value.isNull ? nil : value
                    }

                    try insertRelations(
                        relation: modelRelation, sourcePkId: .integer(sourcePkId),
                        sourceObjectId: .integer(sourceStableId.rawValue),
                        relationTargetObjectIds: relationTargetObjectIds,
                        saveId: info.nextSaveIdValue)

                    // pkIdの取得時にvaluesが存在していることは確定している
                    savedData.updateRelations(
                        relationIds.map(LoadingObjectId.stable), forName: relationName)
                }

                savedDatas.setObjectData(savedData, entityName: entityName, index: index)
            }
        }

        return savedDatas
    }

    func removeRelationsAtSave(
        model: Model, info: OrgelInfo, changedDatas: [Entity.Name: [SavingObjectData]]
    ) throws {
        enum RemoveRelationsAtSaveError: Error {
            case entityNotFound
            case objectIdNotFound
            case relationNotFound
            case objectStableIdNotFound
            case objectStableIdDuplicated
            case inverseEntityNotFound
            case modelRelationNotFound
        }

        // オブジェクトが削除された場合に逆関連があったらデータベース上で関連を外す
        let nextSaveIdValue = info.nextSaveIdValue

        for (entityName, changedEntityDatas) in changedDatas {
            // エンティティごとの処理
            guard let inverseRelationNames = model.entities[entityName]?.inverseRelationNames else {
                throw RemoveRelationsAtSaveError.entityNotFound
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
                    throw RemoveRelationsAtSaveError.objectIdNotFound
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
                        throw RemoveRelationsAtSaveError.relationNotFound
                    }

                    let selectedValues = try selectForSave(
                        entityName: inverseEntityName, relationTable: relation.table,
                        targetObjectIds: targetObjectIds)

                    for attributes in selectedValues {
                        guard let stableId = attributes[.objectId]?.integerValue else {
                            throw RemoveRelationsAtSaveError.objectStableIdNotFound
                        }

                        guard entityAttributes[stableId] == nil else {
                            throw RemoveRelationsAtSaveError.objectStableIdDuplicated
                        }

                        entityAttributes[stableId] = attributes
                    }
                }

                guard !entityAttributes.isEmpty else {
                    continue
                }

                guard let inverseEntity = model.entities[inverseEntityName] else {
                    throw RemoveRelationsAtSaveError.inverseEntityNotFound
                }

                let modelRelations = inverseEntity.relations

                // アトリビュートを元に関連を取得する

                let inverseRemovedDatas = try makeEntityObjectDatas(
                    entityName: inverseEntityName, modelRelations: modelRelations,
                    entityAttributes: entityAttributes.map { $0.value })

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
                    try executeUpdate(
                        entityInsertSql, parameters: .init(attributes))

                    // pk_idを取得してセットする
                    let sourcePkId = SQLValue.integer(lastInsertRowId)

                    for (relationName, relation) in objectData.relations {
                        // データベースに関連のデータを挿入する
                        guard let modelRelation = modelRelations[relationName] else {
                            throw RemoveRelationsAtSaveError.modelRelationNotFound
                        }

                        let relationTargetObjectIds = relation.filter { objectId in
                            return !targetObjectIds.contains(objectId.stable)
                        }.map(\.stable)

                        if !relationTargetObjectIds.isEmpty {
                            try insertRelations(
                                relation: modelRelation, sourcePkId: sourcePkId,
                                sourceObjectId: sourceObjectId,
                                relationTargetObjectIds: .init(relationTargetObjectIds),
                                saveId: nextSaveIdValue)
                        }
                    }
                }
            }
        }
    }

    // 指定したsave_idより大きいsave_idのデータを、全てのエンティティに対してデータベース上から削除する
    func deleteNextToLast(model: Model, saveId: Int64) throws {
        let deleteExprs = SQLWhere.expression(
            .compare(.saveId, .greaterThan, .name(.saveId)))
        let parameters: [SQLParameter.Name: SQLValue] = [.saveId: .integer(saveId)]

        for (entityName, entity) in model.entities {
            try executeUpdate(
                .delete(table: entityName.table, where: deleteExprs),
                parameters: parameters)

            for (_, relation) in entity.relations {
                try executeUpdate(
                    .delete(table: relation.table, where: deleteExprs),
                    parameters: parameters)
            }
        }
    }

    func insertRelations(
        relation: Relation, sourcePkId: SQLValue, sourceObjectId: SQLValue,
        relationTargetObjectIds: [SQLValue], saveId: SQLValue
    ) throws {
        let sql = relation.sqlForInsert

        for relationTargetObjectId in relationTargetObjectIds {
            let parameters: [SQLParameter.Name: SQLValue] = [
                .sourcePkId: sourcePkId,
                .sourceObjectId: sourceObjectId,
                .targetObjectId: relationTargetObjectId,
                .saveId: saveId,
            ]

            try executeUpdate(sql, parameters: parameters)
        }
    }

    func purgeAll(model: Model) throws {
        // DB情報をデータベースから取得
        let info = try fetchInfo()

        if info.currentSaveId < info.lastSaveId {
            // ラストよりカレントのセーブIDが小さければ、カレントより大きいセーブIDのデータを削除
            // つまり、アンドゥした分を削除
            try deleteNextToLast(model: model, saveId: info.currentSaveId)
        }

        let saveIdColumnNames: [SQLColumn.Name] = [.saveId]
        let oneValueParameters: [SQLParameter.Name: SQLValue] = [.saveId: .integer(1)]

        for (entityName, entity) in model.entities {
            // エンティティのデータをパージする（同じオブジェクトIDのデータは最後のものだけ生かす）
            try purgeAttributes(entityName: entityName)

            // 残ったデータのセーブIDを全て1にする
            let updateEntitySql = SQLUpdate.update(
                table: entityName.table, columnNames: saveIdColumnNames)

            try executeUpdate(
                updateEntitySql, parameters: oneValueParameters)

            for (_, relation) in entity.relations {
                let relationTable = relation.table

                // 関連のデータをパージする（同じソースIDのデータは最後のものだけ生かす）
                try purgeRelations(
                    table: relationTable, sourceEntityName: entityName)

                // 残ったデータのセーブIDを全て1にする
                let updateRelationSql = SQLUpdate.update(
                    table: relationTable, columnNames: saveIdColumnNames)

                try executeUpdate(updateRelationSql, parameters: oneValueParameters)
            }
        }
    }

    private func purgeAttributes(entityName: Entity.Name) throws {
        let inExpr = SQLWhere.expression(
            .in(
                field: .not(.pkId),
                source: .select(
                    .init(
                        table: entityName.table, field: .max(.pkId),
                        groupBy: [.objectId]))))
        return try executeUpdate(
            .delete(table: entityName.table, where: inExpr))
    }

    private func purgeRelations(table: SQLTable, sourceEntityName: Entity.Name) throws {
        let select = SQLSelect(table: sourceEntityName.table, field: .column(.pkId))
        let inExpr = SQLWhere.expression(
            .in(field: .not(.sourcePkId), source: .select(select)))
        return try executeUpdate(
            .delete(table: table, where: inExpr))
    }
}

// MARK: - Select

extension SQLiteExecutor {
    public func select(_ select: SQLSelect) throws -> [[SQLColumn.Name: SQLValue]] {
        try executeQuery(
            .select(select), parameters: select.parameters,
            iteration: { iterator in
                var selectResult: [[SQLColumn.Name: SQLValue]] = []

                while iterator.next() {
                    selectResult.append(iterator.values)
                }

                return selectResult
            })
    }

    public func selectSingle(_ select: SQLSelect) -> [SQLColumn.Name: SQLValue]? {
        var select = select
        select.limitRange = .init(location: 0, length: 1)

        return try? self.select(select).first
    }

    func selectForUndo(entityName: Entity.Name, revertSaveId: Int64, currentSaveId: Int64) throws
        -> [[Attribute.Name: SQLValue]]
    {
        enum SelectForUndoError: Error {
            case invalidSaveId
        }

        // リバート先のセーブIDはカレントより小さくないといけない
        guard revertSaveId < currentSaveId else {
            throw SelectForUndoError.invalidSaveId
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

        let selectResult = try self.select(select)

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

        let emptyResult = try self.select(emptySelect)

        // キャッシュを上書きするためのデータを返す
        return .init(selectResult + emptyResult)
    }

    func selectForRedo(entityName: Entity.Name, revertSaveId: Int64, currentSaveId: Int64) throws
        -> [[Attribute.Name: SQLValue]]
    {
        enum SelectForRedoError: Error {
            case invalidSaveId
        }

        // リバート先のセーブIDはカレントより後でないといけない
        guard currentSaveId < revertSaveId else {
            throw SelectForRedoError.invalidSaveId
        }

        // カレントからリドゥ時点の範囲で変更のあったデータを取得して返す
        let option = SQLSelect(
            table: entityName.table,
            where: .expression(.compare(.saveId, .greaterThan, .value(.integer(currentSaveId)))),
            columnOrders: [.init(name: .objectId, order: .ascending)])

        return .init(try selectLast(option, saveId: revertSaveId, includeRemoved: true))
    }

    func selectForRevert(entityName: Entity.Name, revertSaveId: Int64, currentSaveId: Int64) throws
        -> [[Attribute.Name: SQLValue]]
    {
        // リバート先のセーブIDによってアンドゥとリドゥに分岐する
        if revertSaveId < currentSaveId {
            return try selectForUndo(
                entityName: entityName, revertSaveId: revertSaveId, currentSaveId: currentSaveId
            )
        } else if currentSaveId < revertSaveId {
            return try selectForRedo(
                entityName: entityName, revertSaveId: revertSaveId, currentSaveId: currentSaveId
            )
        } else {
            return []
        }
    }

    func selectForSave(
        entityName: Entity.Name, relationTable: SQLTable, targetObjectIds: Set<StableId>
    ) throws -> [[Attribute.Name: SQLValue]] {
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

        return .init(try select(option))
    }

    public func selectLast(_ select: SQLSelect, saveId: Int64, includeRemoved: Bool) throws
        -> [[SQLColumn.Name: SQLValue]]
    {
        var select = select
        select.where =
            .last(
                table: select.table,
                where: select.where,
                lastSaveId: saveId,
                includeRemoved: includeRemoved
            )
        return try self.select(select)
    }

    public func max(table: SQLTable, columnName: SQLColumn.Name) -> SQLValue {
        guard
            let queryResult = try? executeQuery(
                .select(.init(table: table, field: .max(columnName))),
                iteration: { iterator in
                    guard iterator.next() else { return SQLValue.null }
                    return iterator.columnValue(forIndex: 0)
                })
        else {
            return .null
        }

        return queryResult
    }
}

// MARK: - Private

extension SQLiteExecutor {
    // 単独のオブジェクトの全ての関連の関連先のidの配列をDBから取得する
    private func selectRelationIds(
        modelRelations: [Relation.Name: Relation], saveId: Int64, sourceObjectId: Int64
    ) throws -> [Relation.Name: [LoadingObjectId]] {
        var relations: [Relation.Name: [LoadingObjectId]] = [:]

        for (relationName, modelRelation) in modelRelations {
            let relationTable = modelRelation.table

            let relationIds = try selectRelationTargetIds(
                relationTable: relationTable, saveId: saveId, sourceObjectId: sourceObjectId)

            relations[relationName] = relationIds
        }

        return relations
    }

    // 単独の関連の関連先のidの配列をDBから取得する
    private func selectRelationTargetIds(
        relationTable: SQLTable, saveId: Int64, sourceObjectId: Int64
    ) throws -> [LoadingObjectId] {
        enum SelectRelationTargetIdsError: Error {
            case targetObjectIdNotFound
        }

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

        let relations = try self.select(select)

        var relationTargetIds: [LoadingObjectId] = []

        for relation in relations {
            guard let stableId = relation[.targetObjectId]?.integerValue else {
                throw SelectRelationTargetIdsError.targetObjectIdNotFound
            }

            relationTargetIds.append(.stable(.init(stableId)))
        }

        return relationTargetIds
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
