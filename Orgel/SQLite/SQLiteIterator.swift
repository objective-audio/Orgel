import Foundation
import SQLite3

public final class SQLiteIterator {
    private struct Handle {
        let statement: OpaquePointer
        let sqlite: OpaquePointer
    }

    private var handle: Handle?

    private lazy var columnIndices: [String: Int] = {
        guard let handle else { return [:] }

        let columnCount = sqlite3_column_count(handle.statement)
        var dictionary: [String: Int] = [:]
        for index in 0..<columnCount {
            let name = String(cString: sqlite3_column_name(handle.statement, index)).lowercased()
            dictionary[name] = Int(index)
        }
        return dictionary
    }()

    init(statementHandle: OpaquePointer, sqliteHandle: OpaquePointer) {
        handle = .init(statement: statementHandle, sqlite: sqliteHandle)
    }

    deinit {
        if handle != nil {
            assertionFailure("SQLiteIterator is not closed.")
        }
    }

    public func next() -> Bool {
        guard let handle else { return false }

        let resultCode = sqlite3_step(handle.statement)
        let result = resultCode == SQLITE_ROW

        if !result { close() }

        return result
    }

    public var hasRow: Bool {
        guard let handle else { return false }
        return sqlite3_errcode(handle.sqlite) == SQLITE_ROW
    }

    public var columnCount: Int {
        guard let handle else { return 0 }
        return Int(sqlite3_column_count(handle.statement))
    }

    public func columnIndex(forName name: String) -> Int? {
        columnIndices[name.lowercased()]
    }

    public func columnName(forIndex index: Int) -> String? {
        guard let handle else { return nil }
        return String(cString: sqlite3_column_name(handle.statement, Int32(index)))
    }

    public func columnIsNull(forIndex index: Int) -> Bool {
        guard let handle else { return true }
        return sqlite3_column_type(handle.statement, Int32(index)) == SQLITE_NULL
    }

    public func columnIsNull(forName name: String) -> Bool {
        if let index = columnIndex(forName: name) {
            return columnIsNull(forIndex: index)
        } else {
            return true
        }
    }

    public func columnValue(forIndex index: Int) -> SQLValue {
        let columnIndex = Int32(index)
        guard columnIndex >= 0 else { return .null }

        guard let handle else { return .null }

        switch sqlite3_column_type(handle.statement, columnIndex) {
        case SQLITE_INTEGER:
            return .integer(sqlite3_column_int64(handle.statement, columnIndex))
        case SQLITE_FLOAT:
            return .real(sqlite3_column_double(handle.statement, columnIndex))
        case SQLITE_TEXT:
            return .text(String(cString: sqlite3_column_text(handle.statement, columnIndex)))
        case SQLITE_BLOB:
            let dataSize = sqlite3_column_bytes(handle.statement, columnIndex)
            let data = Data(
                bytes: sqlite3_column_blob(handle.statement, columnIndex), count: Int(dataSize))
            return .blob(data)
        default:
            return .null
        }
    }

    public func columnValue(forName name: String) -> SQLValue {
        if let index = columnIndex(forName: name) {
            return columnValue(forIndex: index)
        } else {
            return .null
        }
    }

    public var values: [SQLColumn.Name: SQLValue] {
        guard let handle else { return [:] }

        let columnCount = Int(sqlite3_data_count(handle.statement))

        var dictionary: [SQLColumn.Name: SQLValue] = [:]

        for index in 0..<columnCount {
            guard let name = columnName(forIndex: index) else { continue }
            dictionary[.init(name)] = columnValue(forIndex: index)
        }

        return dictionary
    }

    public func close() {
        guard let handle else { return }
        sqlite3_reset(handle.statement)
        sqlite3_finalize(handle.statement)
        self.handle = nil
    }
}
