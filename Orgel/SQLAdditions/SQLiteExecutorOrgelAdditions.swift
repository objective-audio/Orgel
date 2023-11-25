import Foundation

extension SQLiteExecutor {
    func setup(model: Model) throws -> OrgelInfo {
        enum SetupError: Error {
            case beginTransactionFailed
            case migrationFailed
            case createInfoAndTablesFailed
            case commitFailed
            case fetchInfoFailed
        }

        return try execute {
            guard case .success(()) = beginTransaction() else {
                throw SetupError.beginTransactionFailed
            }

            if tableExists(OrgelInfo.table) {
                // infoのテーブルが存在している場合は、必要があればマイグレーションする
                guard case .success(()) = migrateIfNeeded(model: model) else {
                    let _ = rollback()
                    throw SetupError.migrationFailed
                }
            } else {
                // infoのテーブルが存在していない場合は、新規にテーブルを作成する
                guard case .success(()) = createInfoAndTables(model: model) else {
                    let _ = rollback()
                    throw SetupError.createInfoAndTablesFailed
                }
            }

            guard case .success(()) = commit() else {
                throw SetupError.commitFailed
            }

            guard case let .success(info) = fetchInfo() else {
                throw SetupError.fetchInfoFailed
            }

            return info
        }
    }

    typealias InsertObjectsResult = (
        insertedDatas: [Entity.Name: [LoadingObjectData]], info: OrgelInfo
    )

    func insertObjects(model: Model, values: [Entity.Name: [[Attribute.Name: SQLValue]]])
        throws
        -> InsertObjectsResult
    {
        enum InsertObjectsError: Error {
            case beginTransactionFailed
            case fetchInfoFailed
            case insertFailed
            case updateInfoFailed
            case commitFailed
        }

        return try execute {
            guard case .success(()) = beginTransaction() else {
                throw InsertObjectsError.beginTransactionFailed
            }

            guard case let .success(info) = fetchInfo() else {
                let _ = rollback()
                throw InsertObjectsError.fetchInfoFailed
            }

            // DB上に新規にデータを挿入する
            guard
                case let .success(insertedDatas) = insert(model: model, info: info, values: values)
            else {
                let _ = rollback()
                throw InsertObjectsError.insertFailed
            }

            // DB情報を更新する
            let nextSaveId = info.nextSaveId

            guard
                case let .success(updatedInfo) = updateInfo(
                    currentSaveId: nextSaveId, lastSaveId: nextSaveId)
            else {
                let _ = rollback()
                throw InsertObjectsError.updateInfoFailed
            }

            guard case .success(()) = commit() else {
                throw InsertObjectsError.commitFailed
            }

            return (insertedDatas, updatedInfo)
        }
    }

    // データベースからオブジェクトデータを取得する。条件はFetchOptionで指定
    func fetchObjectDatas(_ option: FetchOption, model: Model) throws -> [Entity.Name:
        [LoadingObjectData]]
    {
        enum FetchObjectDatasError: Error {
            case beginTransactionFailed
            case fetchFailed
            case commitFailed
        }

        return try execute {
            // トランザクション開始
            guard case .success(()) = beginTransaction() else {
                throw FetchObjectDatasError.beginTransactionFailed
            }

            guard case let .success(fetchedDatas) = loadObjectDatas(model: model, option: option)
            else {
                throw FetchObjectDatasError.fetchFailed
            }

            guard case .success(()) = commit() else {
                throw FetchObjectDatasError.commitFailed
            }

            return fetchedDatas
        }
    }

    func clear(model: Model) throws -> OrgelInfo {
        enum ClearError: Error {
            case beginTransactionFailed
            case clearDBFailed
            case updateInfoFailed
            case commitFailed
        }

        return try execute {
            // トランザクション開始
            guard case .success(()) = beginTransaction() else {
                throw ClearError.beginTransactionFailed
            }

            // DBをクリアする
            guard case .success(()) = clearDB(model: model) else {
                let _ = rollback()
                throw ClearError.clearDBFailed
            }

            // infoをクリア。セーブIDを0にする
            guard case let .success(info) = updateInfo(currentSaveId: 0, lastSaveId: 0) else {
                let _ = rollback()
                throw ClearError.updateInfoFailed
            }

            // トランザクション終了
            guard case .success(()) = commit() else {
                throw ClearError.commitFailed
            }

            return info
        }
    }

    typealias SaveResult = (
        savedDatas: [Entity.Name: [LoadingObjectData]], info: OrgelInfo
    )

    func save(model: Model, changedDatas: [Entity.Name: [SavingObjectData]]) throws
        -> SaveResult
    {
        enum SaveError: Error {
            case fetchInfoFailed
            case beginTransactionFailed
            case saveFailed(SQLiteExecutor.SaveError)
            case removeRelationsFailed
            case updateInfoFailed
            case commitFailed
        }

        return try execute {
            // データベースからセーブIDを取得する
            guard case let .success(info) = fetchInfo() else {
                throw SaveError.fetchInfoFailed
            }

            guard !changedDatas.isEmpty else {
                return ([:], info)
            }

            // トランザクション開始
            guard case .success(()) = beginTransaction() else {
                throw SaveError.beginTransactionFailed
            }

            // 変更のあったデータをデータベースに保存する
            let savedDatas: [Entity.Name: [LoadingObjectData]]

            switch save(model: model, info: info, changedDatas: changedDatas) {
            case let .success(value):
                savedDatas = value
            case let .failure(error):
                let _ = rollback()
                throw SaveError.saveFailed(error)
            }

            guard
                case .success(()) = removeRelationsAtSave(
                    model: model, info: info, changedDatas: changedDatas)
            else {
                let _ = rollback()
                throw SaveError.removeRelationsFailed
            }

            let nextSaveId = info.nextSaveId

            guard
                case let .success(updatedInfo) = updateInfo(
                    currentSaveId: nextSaveId, lastSaveId: nextSaveId)
            else {
                let _ = rollback()
                throw SaveError.updateInfoFailed
            }

            guard case .success(()) = commit() else {
                throw SaveError.commitFailed
            }

            return (savedDatas, updatedInfo)
        }
    }

    typealias RevertResult = (
        revertedDatas: [Entity.Name: [LoadingObjectData]], info: OrgelInfo
    )

    func revert(model: Model, revertSaveId: Int64) throws -> RevertResult {
        enum RevertError: Error {
            case beginTransactionFailed
            case fetchInfoFailed
            case invalidSaveId
            case selectForRevertFailed
            case getRelationsFailed
            case makeObjectDatasFailed
            case updateSaveIdFailed
            case commitFailed
        }

        return try execute {
            // トランザクション開始
            guard case .success(()) = beginTransaction() else {
                throw RevertError.beginTransactionFailed
            }

            // カレントとラストのセーブIDをデータベースから取得する
            guard case let .success(info) = fetchInfo() else {
                let _ = rollback()
                throw RevertError.fetchInfoFailed
            }

            let currentSaveId = info.currentSaveId
            let lastSaveId = info.lastSaveId

            let modelEntities = model.entities

            guard revertSaveId != currentSaveId && revertSaveId <= lastSaveId else {
                let _ = rollback()
                throw RevertError.invalidSaveId
            }

            var revertedAttributes: [Entity.Name: [[Attribute.Name: SQLValue]]] = [:]

            for (entityName, _) in modelEntities {
                // リバートするためのデータをデータベースから取得する
                // カレントとの位置によってredoかundoが内部で呼ばれる
                guard
                    case let .success(selectResult) = selectForRevert(
                        entityName: entityName, revertSaveId: revertSaveId,
                        currentSaveId: currentSaveId)
                else {
                    let _ = rollback()
                    throw RevertError.selectForRevertFailed
                }

                revertedAttributes[entityName] = selectResult
            }

            var revertedDatas: [Entity.Name: [LoadingObjectData]] = [:]

            for (entityName, entityAttributes) in revertedAttributes {
                guard let modelRelation = model.entities[entityName]?.relations else {
                    let _ = rollback()
                    throw RevertError.getRelationsFailed
                }

                // アトリビュートのみのデータから関連のデータを加えてobject_dataを生成する
                guard
                    case let .success(objectDatas) = makeEntityObjectDatas(
                        entityName: entityName, modelRelations: modelRelation,
                        entityAttributes: entityAttributes)
                else {
                    let _ = rollback()
                    throw RevertError.makeObjectDatasFailed
                }

                revertedDatas[entityName] = objectDatas
            }

            // リバートしたセーブIDでinfoを更新する
            guard case let .success(updatedInfo) = updateCurrentSaveId(revertSaveId) else {
                let _ = rollback()
                throw RevertError.updateSaveIdFailed
            }

            // トランザクション終了
            guard case .success(()) = commit() else {
                throw RevertError.commitFailed
            }

            return (revertedDatas, updatedInfo)
        }
    }

    func purge(model: Model) throws -> OrgelInfo {
        enum PurgeError: Error {
            case beginTransactionFailed
            case purgeFailed
            case updateInfoFailed
            case commitFailed
            case vacuumFailed
        }

        return try execute {
            // トランザクション開始
            guard case .success(()) = beginTransaction() else {
                throw PurgeError.beginTransactionFailed
            }

            guard case .success(()) = purgeAll(model: model) else {
                let _ = rollback()
                throw PurgeError.purgeFailed
            }

            // infoをクリア。セーブIDを1にする
            guard case let .success(info) = updateInfo(currentSaveId: 1, lastSaveId: 1) else {
                let _ = rollback()
                throw PurgeError.updateInfoFailed
            }

            // トランザクション終了
            guard case .success(()) = commit() else {
                throw PurgeError.commitFailed
            }

            // バキュームする（バキュームはトランザクション中はできない）
            guard case .success(()) = executeUpdate(.vacuum) else {
                throw PurgeError.vacuumFailed
            }

            return info
        }
    }
}

extension SQLiteExecutor {
    private enum ExecuteError: Error {
        case openFailed
    }

    private func execute<Success>(
        _ execution: () throws -> Success
    ) throws -> Success {
        guard open() else { throw ExecuteError.openFailed }
        defer { close() }

        return try execution()
    }
}
