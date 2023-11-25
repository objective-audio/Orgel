import Foundation
import SQLite3

public actor SQLiteExecutor {
    public typealias UpdateResult = Result<Void, SQLiteError>

    public enum QueryError: Error {
        case sqlite(SQLiteError)
        case iteration(Error)
    }

    public enum IterationError: Error {
        case contentNotFound
        case invalidContent
    }

    public static var libVersion: String { String(cString: sqlite3_libversion()) }
    public static var isThreadSafe: Bool { sqlite3_threadsafe() != 0 }

    public let url: URL
    private var sqliteHandle: OpaquePointer? = nil
    public var hasSqliteHandle: Bool { sqliteHandle != nil }

    public init(url: URL) {
        self.url = url
    }

    deinit {
        if sqliteHandle != nil {
            assertionFailure("SQLiteExecutor is not closed.")
        }
    }

    public func open() -> Bool {
        if sqliteHandle != nil {
            return true
        }

        let resultCode = sqlite3_open(
            url.absoluteString.cString(using: .utf8), &sqliteHandle)

        guard resultCode == SQLITE_OK else {
            return false
        }

        let updateResult = executeUpdate(.raw("pragma foreign_keys = ON;"))

        switch updateResult {
        case .success:
            return true
        case .failure:
            return false
        }
    }

    public func close() {
        guard let sqliteHandle else {
            return
        }

        var retry = false
        var isFinalizingTried = false

        repeat {
            retry = false
            let resultCode = sqlite3_close(sqliteHandle)
            if SQLITE_BUSY == resultCode || SQLITE_LOCKED == resultCode {
                if !isFinalizingTried {
                    isFinalizingTried = true

                    while let stmt = sqlite3_next_stmt(sqliteHandle, nil) {
                        sqlite3_finalize(stmt)
                        retry = true
                    }
                }
            }
        } while retry

        self.sqliteHandle = nil
    }

    public var goodConnection: Bool {
        do {
            try executeQuery(
                .select(
                    .init(
                        table: .sqliteMaster, field: .column(.System.name),
                        where: .expression(.raw("type = 'table'"))))
            ) { _ in
                ()
            }
            .get()
            return true
        } catch {
            return false
        }
    }

    public var integrityCheck: Bool {
        do {
            try executeQuery(.raw("pragma integrity_check;")) { iterator in
                guard iterator.next(),
                    case let .text(text) = iterator.columnValue(forName: "integrity_check")
                else {
                    throw IterationError.contentNotFound
                }

                guard text.lowercased() == "ok" else {
                    throw IterationError.invalidContent
                }
            }.get()
            return true
        } catch {
            return false
        }
    }

    public var lastInsertRowId: Int64 {
        sqlite3_last_insert_rowid(sqliteHandle)
    }

    public var lastErrorMessage: String { String(cString: sqlite3_errmsg(sqliteHandle)) }
    public var lastErrorCode: Int32 { sqlite3_errcode(sqliteHandle) }
    public var hadError: Bool {
        let code = lastErrorCode
        return SQLITE_OK < code && code < SQLITE_ROW
    }
}

extension SQLiteExecutor {
    public func executeUpdate(_ sql: SQLUpdate, parameters: [SQLParameter.Name: SQLValue] = [:])
        -> UpdateResult
    {
        guard let sqliteHandle else { return .failure(.init(kind: .closed)) }

        var statementHandle: OpaquePointer?

        let prepareResult = SQLiteResult(
            rawValue: sqlite3_prepare_v2(
                sqliteHandle, sql.sqlStringValue.cString(using: .utf8), -1, &statementHandle, nil))

        guard let statementHandle else {
            return .failure(
                .init(kind: .prepareFailed, result: prepareResult, message: lastErrorMessage))
        }

        guard prepareResult.isSuccess else {
            sqlite3_finalize(statementHandle)
            return .failure(
                .init(kind: .prepareFailed, result: prepareResult, message: lastErrorMessage))
        }

        let bindedCount: Int
        let queryCount = sqlite3_bind_parameter_count(statementHandle)

        if parameters.count == queryCount {
            var index: Int = 0
            for (key, value) in parameters {
                let namedIdx = sqlite3_bind_parameter_index(
                    statementHandle, key.sqlStringValue.cString(using: .utf8))
                if namedIdx > 0 {
                    bind(value: value, columnIdx: namedIdx, stmt: statementHandle)
                    index += 1
                }
            }
            bindedCount = index
        } else {
            bindedCount = 0
        }

        guard bindedCount == queryCount else {
            sqlite3_finalize(statementHandle)
            return .failure(.init(kind: .invalidQueryCount))
        }

        let stepResult = SQLiteResult(rawValue: sqlite3_step(statementHandle))

        guard stepResult.rawValue != SQLITE_ROW else {
            return .failure(
                .init(
                    kind: .stepFailed, result: stepResult,
                    message: "executeUpdate is being called with a query string '\(sql)'."))
        }

        let stepErrorMessage = lastErrorMessage

        let finalizeResult = SQLiteResult(rawValue: sqlite3_finalize(statementHandle))

        guard finalizeResult.isSuccess else {
            return .failure(
                .init(kind: .finalizeFailed, result: stepResult, message: lastErrorMessage))
        }

        if stepResult.isSuccess {
            return .success(())
        } else {
            return .failure(.init(kind: .stepFailed, result: stepResult, message: stepErrorMessage))
        }
    }

    public func executeQuery<Success>(
        _ sql: SQLQuery, parameters: [SQLParameter.Name: SQLValue] = [:],
        iteration: @Sendable (SQLiteIterator) throws -> Success
    ) -> Result<Success, QueryError> {
        switch executeQuery(sql, parameters: parameters) {
        case let .success(iterator):
            defer { iterator.close() }

            do {
                let result = try iteration(iterator)
                return .success(result)
            } catch {
                return .failure(.iteration(error))
            }
        case let .failure(error):
            return .failure(.sqlite(error))
        }
    }

    private func executeQuery(_ sql: SQLQuery, parameters: [SQLParameter.Name: SQLValue])
        -> Result<
            SQLiteIterator, SQLiteError
        >
    {
        guard let sqliteHandle else { return .failure(.init(kind: .closed)) }

        var statementHandle: OpaquePointer?

        let resultCode = SQLiteResult(
            rawValue: sqlite3_prepare_v2(
                sqliteHandle, sql.sqlStringValue.cString(using: .utf8), -1, &statementHandle, nil))

        guard resultCode.isSuccess, let statementHandle else {
            sqlite3_finalize(statementHandle)
            return .failure(
                .init(kind: .prepareFailed, result: resultCode, message: lastErrorMessage))
        }

        let bindedCount: Int
        let queryCount = sqlite3_bind_parameter_count(statementHandle)

        if parameters.count == queryCount {
            var index: Int = 0
            for (key, value) in parameters {
                let namedIdx = sqlite3_bind_parameter_index(
                    statementHandle, key.sqlStringValue.cString(using: .utf8))
                if namedIdx > 0 {
                    bind(value: value, columnIdx: namedIdx, stmt: statementHandle)
                    index += 1
                }
            }
            bindedCount = index
        } else {
            bindedCount = 0
        }

        guard bindedCount == queryCount else {
            sqlite3_finalize(statementHandle)
            return .failure(
                .init(kind: .invalidQueryCount))
        }

        return .success(.init(statementHandle: statementHandle, sqliteHandle: sqliteHandle))
    }

    private func bind(value: SQLValue, columnIdx: Int32, stmt: OpaquePointer) {
        switch value {
        case .null:
            sqlite3_bind_null(stmt, columnIdx)
        case let .integer(integerValue):
            sqlite3_bind_int64(stmt, columnIdx, sqlite3_int64(integerValue))
        case let .real(realValue):
            sqlite3_bind_double(stmt, columnIdx, realValue)
        case let .text(textValue):
            sqlite3_bind_text(
                stmt, columnIdx, (textValue as NSString).utf8String, -1, nil)
        case let .blob(blobValue):
            sqlite3_bind_blob(
                stmt, columnIdx, (blobValue as NSData).bytes, Int32(blobValue.count), nil)
        }
    }
}

extension SQLiteExecutor {
    public func createTable(_ table: SQLTable, columns: [SQLColumn]) -> UpdateResult {
        executeUpdate(.createTable(table, columns: columns))
    }

    public func alterTable(_ table: SQLTable, column: SQLColumn) -> UpdateResult {
        executeUpdate(.alterTable(table, column: column))
    }

    public func dropTable(_ table: SQLTable) -> UpdateResult {
        executeUpdate(.dropTable(table))
    }

    public func createIndex(_ index: SQLIndex, table: SQLTable, columnNames: [SQLColumn.Name])
        -> UpdateResult
    {
        executeUpdate(.createIndex(index, table: table, columnNames: columnNames))
    }

    public func dropIndex(_ index: SQLIndex) -> UpdateResult {
        executeUpdate(.dropIndex(index))
    }

    public func tableExists(_ table: SQLTable) -> Bool {
        do {
            let _ = try tableSchema(table).get()
            return true
        } catch {
            return false
        }
    }

    public func indexExists(_ index: SQLIndex) -> Bool {
        do {
            let _ = try indexSchema(index).get()
            return true
        } catch {
            return false
        }
    }

    public func columnExists(columnName: String, tableName: String) -> Bool {
        let lowerTableName = tableName.lowercased()
        let lowerColumnName = columnName.lowercased()

        guard let schema = try? tableSchema(.init(lowerTableName)).get() else {
            return false
        }

        for dictionary in schema {
            if case let .text(name) = dictionary[.System.name], name.lowercased() == lowerColumnName
            {
                return true
            }
        }

        return false
    }

    public func schema() -> Result<[[SQLColumn.Name: SQLValue]], QueryError> {
        executeQuery(
            .raw(
                "select type, name, tbl_name, rootpage, sql from (select * from sqlite_master union all select * from sqlite_temp_master) where type != 'meta' and name not like 'sqlite_%' order by tbl_name, type desc, name"
            )
        ) { iterator in
            var result: [[SQLColumn.Name: SQLValue]] = []
            while iterator.next() {
                result.append(iterator.values)
            }
            guard !result.isEmpty else {
                throw IterationError.contentNotFound
            }
            return result
        }
    }

    public func tableSchema(_ table: SQLTable) -> Result<[[SQLColumn.Name: SQLValue]], QueryError> {
        executeQuery(.raw("PRAGMA table_info('" + table.sqlStringValue + "')")) { iterator in
            var result: [[SQLColumn.Name: SQLValue]] = []
            while iterator.next() {
                result.append(iterator.values)
            }
            guard !result.isEmpty else {
                throw IterationError.contentNotFound
            }
            return result
        }
    }

    public func indexSchema(_ index: SQLIndex) -> Result<[SQLColumn.Name: SQLValue], QueryError> {
        executeQuery(
            .select(
                .init(
                    table: .sqliteMaster, field: .wildcard,
                    where: .and([
                        .expression(.raw("type = 'index'")),
                        .expression(.raw("name = '" + index.sqlStringValue + "'")),
                    ])))
        ) { iterator in
            guard iterator.next() else { throw IterationError.contentNotFound }
            return iterator.values
        }
    }

    public func beginTransaction() -> UpdateResult {
        executeUpdate(.beginTransation)
    }

    public func commit() -> UpdateResult {
        executeUpdate(.commitTransaction)
    }

    public func rollback() -> UpdateResult {
        executeUpdate(.rollbackTransaction)
    }
}
