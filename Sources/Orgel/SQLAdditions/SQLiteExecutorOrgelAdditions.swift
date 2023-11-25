import Foundation

extension SQLiteExecutor {
    func setup(model: Model) throws -> OrgelInfo {
        try execute {
            try beginTransaction()

            do {
                if tableExists(OrgelInfo.table) {
                    // infoのテーブルが存在している場合は、必要があればマイグレーションする
                    try migrateIfNeeded(model: model)
                } else {
                    // infoのテーブルが存在していない場合は、新規にテーブルを作成する
                    try createInfoAndTables(model: model)
                }
            } catch {
                _ = try? rollback()
                throw error
            }

            try commit()

            return try fetchInfo()
        }
    }

    typealias InsertObjectsResult = (
        insertedDatas: [Entity.Name: [LoadingObjectData]], info: OrgelInfo
    )

    func insertObjects(model: Model, values: [Entity.Name: [[Attribute.Name: SQLValue]]]) throws
        -> InsertObjectsResult
    {
        return try execute {
            try beginTransaction()

            let insertedDatas: [Entity.Name: [LoadingObjectData]]
            let updatedInfo: OrgelInfo

            do {
                let info = try fetchInfo()

                // DB上に新規にデータを挿入する
                insertedDatas = try insert(model: model, info: info, values: values)

                // DB情報を更新する
                let nextSaveId = info.nextSaveId

                updatedInfo = try updateInfo(currentSaveId: nextSaveId, lastSaveId: nextSaveId)
            } catch {
                _ = try? rollback()
                throw error
            }

            try commit()

            return (insertedDatas, updatedInfo)
        }
    }

    // データベースからオブジェクトデータを取得する。条件はFetchOptionで指定
    func fetchObjectDatas(_ option: FetchOption, model: Model) throws -> [Entity.Name:
        [LoadingObjectData]]
    {
        return try execute {
            // トランザクション開始
            try beginTransaction()

            let fetchedDatas = try loadObjectDatas(model: model, option: option)

            try commit()

            return fetchedDatas
        }
    }

    func clear(model: Model) throws -> OrgelInfo {
        return try execute {
            // トランザクション開始
            try beginTransaction()

            let info: OrgelInfo

            do {
                // DBをクリアする
                try clearDB(model: model)

                // infoをクリア。セーブIDを0にする
                info = try updateInfo(currentSaveId: 0, lastSaveId: 0)
            } catch {
                _ = try? rollback()
                throw error
            }

            // トランザクション終了
            try commit()

            return info
        }
    }

    typealias SaveResult = (
        savedDatas: [Entity.Name: [LoadingObjectData]], info: OrgelInfo
    )

    func save(model: Model, changedDatas: [Entity.Name: [SavingObjectData]]) throws
        -> SaveResult
    {
        try execute {
            // データベースからセーブIDを取得する
            let info = try fetchInfo()

            guard !changedDatas.isEmpty else {
                return ([:], info)
            }

            // トランザクション開始
            try beginTransaction()

            // 変更のあったデータをデータベースに保存する
            let savedDatas: [Entity.Name: [LoadingObjectData]]
            let updatedInfo: OrgelInfo

            do {
                savedDatas = try save(model: model, info: info, changedDatas: changedDatas)

                try removeRelationsAtSave(
                    model: model, info: info, changedDatas: changedDatas)

                let nextSaveId = info.nextSaveId

                updatedInfo = try updateInfo(
                    currentSaveId: nextSaveId, lastSaveId: nextSaveId)
            } catch {
                let _ = try? rollback()
                throw error
            }

            try commit()

            return (savedDatas, updatedInfo)
        }
    }

    typealias RevertResult = (
        revertedDatas: [Entity.Name: [LoadingObjectData]], info: OrgelInfo
    )

    func revert(model: Model, revertSaveId: Int64) throws -> RevertResult {
        try execute {
            enum RevertError: Error {
                case invalidSaveId
                case getRelationsFailed
            }

            // トランザクション開始
            try beginTransaction()

            var revertedDatas: [Entity.Name: [LoadingObjectData]] = [:]
            let updatedInfo: OrgelInfo

            do {
                // カレントとラストのセーブIDをデータベースから取得する
                let info = try fetchInfo()

                let currentSaveId = info.currentSaveId
                let lastSaveId = info.lastSaveId

                let modelEntities = model.entities

                guard revertSaveId != currentSaveId && revertSaveId <= lastSaveId else {
                    throw RevertError.invalidSaveId
                }

                var revertedAttributes: [Entity.Name: [[Attribute.Name: SQLValue]]] = [:]

                for (entityName, _) in modelEntities {
                    // リバートするためのデータをデータベースから取得する
                    // カレントとの位置によってredoかundoが内部で呼ばれる
                    let selectResult = try selectForRevert(
                        entityName: entityName, revertSaveId: revertSaveId,
                        currentSaveId: currentSaveId)

                    revertedAttributes[entityName] = selectResult
                }

                for (entityName, entityAttributes) in revertedAttributes {
                    guard let modelRelation = model.entities[entityName]?.relations else {
                        throw RevertError.getRelationsFailed
                    }

                    // アトリビュートのみのデータから関連のデータを加えてobject_dataを生成する
                    let objectDatas = try makeEntityObjectDatas(
                        entityName: entityName, modelRelations: modelRelation,
                        entityAttributes: entityAttributes)

                    revertedDatas[entityName] = objectDatas
                }

                // リバートしたセーブIDでinfoを更新する
                updatedInfo = try updateCurrentSaveId(revertSaveId)
            } catch {
                _ = try? rollback()
                throw error
            }

            // トランザクション終了
            try commit()

            return (revertedDatas, updatedInfo)
        }
    }

    func purge(model: Model) throws -> OrgelInfo {
        try execute {
            enum PurgeError: Error {
                case beginTransactionFailed
                case purgeFailed
                case updateInfoFailed
                case commitFailed
                case vacuumFailed
            }

            // トランザクション開始
            try beginTransaction()

            let info: OrgelInfo

            do {
                try purgeAll(model: model)

                // infoをクリア。セーブIDを1にする
                info = try updateInfo(currentSaveId: 1, lastSaveId: 1)
            } catch {
                _ = try? rollback()
                throw error
            }

            // トランザクション終了
            try commit()

            // バキュームする（バキュームはトランザクション中はできない）
            try executeUpdate(.vacuum)

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
