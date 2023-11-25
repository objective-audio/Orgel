import XCTest

@testable import Orgel

final class SQLColumnInternalTests: XCTestCase {
    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
    }

    func testFull() throws {
        let column = SQLColumn(
            name: .init("test_name"), valueType: .integer, primary: true, unique: true,
            notNull: true, defaultValue: .integer(5))

        XCTAssertEqual(
            column.sqlStringValue,
            "test_name INTEGER PRIMARY KEY AUTOINCREMENT UNIQUE NOT NULL DEFAULT 5")
    }

    func testShort() throws {
        let column = SQLColumn(name: .init("test_name"), valueType: .text)

        XCTAssertEqual(column.sqlStringValue, "test_name TEXT")
    }
}
