import Orgel
import SQLite3
import XCTest

final class SQLiteErrorTests: XCTestCase {
    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
    }

    func testInitWithTypeOnly() {
        let error = SQLiteError(kind: .sqlite)

        XCTAssertEqual(error.kind, .sqlite)
        XCTAssertEqual(error.result.rawValue, SQLITE_OK)
        XCTAssertEqual(error.message, "")
    }

    func testInitWithoutMessage() {
        let error = SQLiteError(kind: .sqlite, result: .init(rawValue: SQLITE_INTERNAL))

        XCTAssertEqual(error.kind, .sqlite)
        XCTAssertEqual(error.result.rawValue, SQLITE_INTERNAL)
        XCTAssertEqual(error.message, "")
    }

    func testInitWithAllParameters() {
        let error = SQLiteError(
            kind: .closed, result: .init(rawValue: SQLITE_ERROR), message: "test_message")

        XCTAssertEqual(error.kind, .closed)
        XCTAssertEqual(error.result.rawValue, SQLITE_ERROR)
        XCTAssertEqual(error.message, "test_message")
    }
}
