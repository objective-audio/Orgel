import XCTest

@testable import Orgel

final class SQLSelectInternalTests: XCTestCase {
    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
    }

    func testColumnOrderAscending() {
        let order = SQLSelect.ColumnOrder(name: .init("a"), order: .ascending)
        XCTAssertEqual(order.sqlStringValue, "a ASC")
    }

    func testColumnOrderDescending() {
        let order = SQLSelect.ColumnOrder(name: .init("b"), order: .descending)
        XCTAssertEqual(order.sqlStringValue, "b DESC")
    }

    func testRange() {
        let range = SQLSelect.Range(location: 1, length: 2)
        XCTAssertEqual(range.sqlStringValue, "1, 2")
    }

    func testSqlStringValue() {
        let select = SQLSelect(
            table: .init("test_table"),
            field: .columns([.init("column_a"), .init("column_b")]),
            where: .expression(.raw("abc = :def")),
            columnOrders: [
                .init(name: .init("column_c"), order: .ascending),
                .init(name: .init("column_d"), order: .descending),
            ], limitRange: .init(location: 10, length: 20), groupBy: [.init("ghi")], distinct: true)

        XCTAssertEqual(
            select.sqlStringValue,
            "SELECT DISTINCT column_a, column_b FROM test_table WHERE abc = :def ORDER BY column_c ASC, column_d DESC LIMIT 10, 20 GROUP BY ghi"
        )
    }

    func testColumnOrderArraySqlStringValue() {
        let columnOrders = [
            SQLSelect.ColumnOrder(name: .init("column_a"), order: .ascending),
            SQLSelect.ColumnOrder(name: .init("column_b"), order: .descending),
        ]

        XCTAssertEqual(columnOrders.sqlStringValue, "column_a ASC, column_b DESC")
    }
}
