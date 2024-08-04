import Foundation
import SQLite3

public actor SQLiteExecutor {
    public static var libVersion: String { String(cString: sqlite3_libversion()) }
    public static var isThreadSafe: Bool { sqlite3_threadsafe() != 0 }

    public let url: URL
    private var sqliteHandle: OpaquePointer? = nil
    public var hasSqliteHandle: Bool { sqliteHandle != nil }

    public init(url: URL) {
        self.url = url
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

        do {
            try executeUpdate(.raw("pragma foreign_keys = ON;"))
            return true
        } catch {
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
            return true
        } catch {
            return false
        }
    }

    public var integrityCheck: Bool {
        enum IntegrityCheckError: Error {
            case columnNotFound
            case notOK
        }

        do {
            try executeQuery(.raw("pragma integrity_check;")) { iterator in
                guard iterator.next(),
                    case let .text(text) = iterator.columnValue(forName: "integrity_check")
                else {
                    throw IntegrityCheckError.columnNotFound
                }

                guard text.lowercased() == "ok" else {
                    throw IntegrityCheckError.notOK
                }
            }
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
        throws
    {
        guard let sqliteHandle else {
            throw SQLiteError(kind: .closed)
        }

        var statementHandle: OpaquePointer?

        let prepareResult = SQLiteResult(
            rawValue: sqlite3_prepare_v2(
                sqliteHandle, sql.sqlStringValue.cString(using: .utf8), -1, &statementHandle, nil))

        guard let statementHandle else {
            throw SQLiteError(
                kind: .prepareFailed, result: prepareResult, message: lastErrorMessage)
        }

        guard prepareResult.isSuccess else {
            sqlite3_finalize(statementHandle)
            throw SQLiteError(
                kind: .prepareFailed, result: prepareResult, message: lastErrorMessage)
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
            throw SQLiteError(kind: .invalidQueryCount)
        }

        let stepResult = SQLiteResult(rawValue: sqlite3_step(statementHandle))

        guard stepResult.rawValue != SQLITE_ROW else {
            throw SQLiteError(
                kind: .stepFailed, result: stepResult,
                message: "executeUpdate is being called with a query string '\(sql)'.")
        }

        let stepErrorMessage = lastErrorMessage

        let finalizeResult = SQLiteResult(rawValue: sqlite3_finalize(statementHandle))

        guard finalizeResult.isSuccess else {
            throw SQLiteError(kind: .finalizeFailed, result: stepResult, message: lastErrorMessage)
        }

        if stepResult.isSuccess {
            return
        } else {
            throw SQLiteError(kind: .stepFailed, result: stepResult, message: stepErrorMessage)
        }
    }

    public func executeQuery<Success>(
        _ sql: SQLQuery, parameters: [SQLParameter.Name: SQLValue] = [:],
        iteration: @Sendable (SQLiteIterator) throws -> Success
    ) throws -> Success {
        let iterator = try executeQuery(sql, parameters: parameters)
        defer { iterator.close() }

        return try iteration(iterator)
    }

    private func executeQuery(_ sql: SQLQuery, parameters: [SQLParameter.Name: SQLValue]) throws
        -> SQLiteIterator
    {
        guard let sqliteHandle else {
            throw SQLiteError(kind: .closed)
        }

        var statementHandle: OpaquePointer?

        let resultCode = SQLiteResult(
            rawValue: sqlite3_prepare_v2(
                sqliteHandle, sql.sqlStringValue.cString(using: .utf8), -1, &statementHandle, nil))

        guard resultCode.isSuccess, let statementHandle else {
            sqlite3_finalize(statementHandle)
            throw SQLiteError(kind: .prepareFailed, result: resultCode, message: lastErrorMessage)
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
            throw SQLiteError(kind: .invalidQueryCount)
        }

        return .init(statementHandle: statementHandle, sqliteHandle: sqliteHandle)
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
    public func createTable(_ table: SQLTable, columns: [SQLColumn]) throws {
        try executeUpdate(.createTable(table, columns: columns))
    }

    public func alterTable(_ table: SQLTable, column: SQLColumn) throws {
        try executeUpdate(.alterTable(table, column: column))
    }

    public func dropTable(_ table: SQLTable) throws {
        try executeUpdate(.dropTable(table))
    }

    public func createIndex(_ index: SQLIndex, table: SQLTable, columnNames: [SQLColumn.Name])
        throws
    {
        try executeUpdate(.createIndex(index, table: table, columnNames: columnNames))
    }

    public func dropIndex(_ index: SQLIndex) throws {
        try executeUpdate(.dropIndex(index))
    }

    public func tableExists(_ table: SQLTable) -> Bool {
        do {
            let _ = try tableSchema(table)
            return true
        } catch {
            return false
        }
    }

    public func indexExists(_ index: SQLIndex) -> Bool {
        do {
            let _ = try indexSchema(index)
            return true
        } catch {
            return false
        }
    }

    public func columnExists(columnName: String, tableName: String) -> Bool {
        let lowerTableName = tableName.lowercased()
        let lowerColumnName = columnName.lowercased()

        guard let schema = try? tableSchema(.init(lowerTableName)) else {
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

    public func schema() throws -> [[SQLColumn.Name: SQLValue]] {
        return try executeQuery(
            .raw(
                "select type, name, tbl_name, rootpage, sql from (select * from sqlite_master union all select * from sqlite_temp_master) where type != 'meta' and name not like 'sqlite_%' order by tbl_name, type desc, name"
            )
        ) { iterator in
            enum SchemeError: Error {
                case valuesNotFound
            }

            var result: [[SQLColumn.Name: SQLValue]] = []
            while iterator.next() {
                result.append(iterator.values)
            }
            guard !result.isEmpty else {
                throw SchemeError.valuesNotFound
            }
            return result
        }
    }

    public func tableSchema(_ table: SQLTable) throws -> [[SQLColumn.Name: SQLValue]] {
        try executeQuery(.raw("PRAGMA table_info('" + table.sqlStringValue + "')")) { iterator in
            enum TableSchemaError: Error {
                case valuesNotFound
            }

            var result: [[SQLColumn.Name: SQLValue]] = []
            while iterator.next() {
                result.append(iterator.values)
            }
            guard !result.isEmpty else {
                throw TableSchemaError.valuesNotFound
            }
            return result
        }
    }

    public func indexSchema(_ index: SQLIndex) throws -> [SQLColumn.Name: SQLValue] {
        try executeQuery(
            .select(
                .init(
                    table: .sqliteMaster, field: .wildcard,
                    where: .and([
                        .expression(.raw("type = 'index'")),
                        .expression(.raw("name = '" + index.sqlStringValue + "'")),
                    ])))
        ) { iterator in
            enum IndexSchemaError: Error {
                case valuesNotFound
            }

            guard iterator.next() else {
                throw IndexSchemaError.valuesNotFound
            }
            return iterator.values
        }
    }

    public func beginTransaction() throws {
        try executeUpdate(.beginTransation)
    }

    public func commit() throws {
        try executeUpdate(.commitTransaction)
    }

    public func rollback() throws {
        try executeUpdate(.rollbackTransaction)
    }
}
