import Orgel
import SQLite3
import XCTest

final class SQLiteResultTests: XCTestCase {
    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
    }

    func testInit() {
        let result = SQLiteResult(rawValue: SQLITE_DONE)

        XCTAssertEqual(result.rawValue, SQLITE_DONE)
    }

    func testDescription() throws {
        XCTAssertEqual(SQLiteResult(rawValue: SQLITE_ROW).description, "SQLITE_ROW")
        XCTAssertEqual(SQLiteResult(rawValue: SQLITE_DONE).description, "SQLITE_DONE")
        XCTAssertEqual(SQLiteResult(rawValue: SQLITE_OK).description, "SQLITE_OK")
        XCTAssertEqual(SQLiteResult(rawValue: SQLITE_ERROR).description, "SQLITE_ERROR")
        XCTAssertEqual(SQLiteResult(rawValue: SQLITE_INTERNAL).description, "SQLITE_INTERNAL")
        XCTAssertEqual(SQLiteResult(rawValue: SQLITE_PERM).description, "SQLITE_PERM")
        XCTAssertEqual(SQLiteResult(rawValue: SQLITE_ABORT).description, "SQLITE_ABORT")
        XCTAssertEqual(SQLiteResult(rawValue: SQLITE_BUSY).description, "SQLITE_BUSY")
        XCTAssertEqual(SQLiteResult(rawValue: SQLITE_LOCKED).description, "SQLITE_LOCKED")
        XCTAssertEqual(SQLiteResult(rawValue: SQLITE_NOMEM).description, "SQLITE_NOMEM")
        XCTAssertEqual(SQLiteResult(rawValue: SQLITE_READONLY).description, "SQLITE_READONLY")
        XCTAssertEqual(SQLiteResult(rawValue: SQLITE_INTERRUPT).description, "SQLITE_INTERRUPT")
        XCTAssertEqual(SQLiteResult(rawValue: SQLITE_IOERR).description, "SQLITE_IOERR")
        XCTAssertEqual(SQLiteResult(rawValue: SQLITE_CORRUPT).description, "SQLITE_CORRUPT")
        XCTAssertEqual(SQLiteResult(rawValue: SQLITE_NOTFOUND).description, "SQLITE_NOTFOUND")
        XCTAssertEqual(SQLiteResult(rawValue: SQLITE_FULL).description, "SQLITE_FULL")
        XCTAssertEqual(SQLiteResult(rawValue: SQLITE_CANTOPEN).description, "SQLITE_CANTOPEN")
        XCTAssertEqual(SQLiteResult(rawValue: SQLITE_PROTOCOL).description, "SQLITE_PROTOCOL")
        XCTAssertEqual(SQLiteResult(rawValue: SQLITE_EMPTY).description, "SQLITE_EMPTY")
        XCTAssertEqual(SQLiteResult(rawValue: SQLITE_SCHEMA).description, "SQLITE_SCHEMA")
        XCTAssertEqual(SQLiteResult(rawValue: SQLITE_TOOBIG).description, "SQLITE_TOOBIG")
        XCTAssertEqual(SQLiteResult(rawValue: SQLITE_CONSTRAINT).description, "SQLITE_CONSTRAINT")
        XCTAssertEqual(SQLiteResult(rawValue: SQLITE_MISMATCH).description, "SQLITE_MISMATCH")
        XCTAssertEqual(SQLiteResult(rawValue: SQLITE_MISUSE).description, "SQLITE_MISUSE")
        XCTAssertEqual(SQLiteResult(rawValue: SQLITE_NOLFS).description, "SQLITE_NOLFS")
        XCTAssertEqual(SQLiteResult(rawValue: SQLITE_AUTH).description, "SQLITE_AUTH")
        XCTAssertEqual(SQLiteResult(rawValue: SQLITE_FORMAT).description, "SQLITE_FORMAT")
        XCTAssertEqual(SQLiteResult(rawValue: SQLITE_RANGE).description, "SQLITE_RANGE")
        XCTAssertEqual(SQLiteResult(rawValue: SQLITE_NOTADB).description, "SQLITE_NOTADB")
        XCTAssertEqual(SQLiteResult(rawValue: SQLITE_NOTICE).description, "SQLITE_NOTICE")
        XCTAssertEqual(SQLiteResult(rawValue: SQLITE_WARNING).description, "SQLITE_WARNING")

        XCTAssertEqual(SQLiteResult(rawValue: 10000).description, "unknown")
    }

    func testIsSuccess() {
        XCTAssertTrue(SQLiteResult(rawValue: SQLITE_DONE).isSuccess)
        XCTAssertTrue(SQLiteResult(rawValue: SQLITE_OK).isSuccess)

        XCTAssertFalse(SQLiteResult(rawValue: SQLITE_ROW).isSuccess)
        XCTAssertFalse(SQLiteResult(rawValue: SQLITE_ERROR).isSuccess)
    }
}
