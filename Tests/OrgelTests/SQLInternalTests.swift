import XCTest

@testable import Orgel

final class SQLInternalTests: XCTestCase {
    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
    }

    func testCreateTable() {
        XCTAssertEqual(
            SQLUpdate.createTable(
                .init("test_table"),
                columns: [
                    .init(name: .init("column_a"), valueType: .integer),
                    .init(name: .init("column_b"), valueType: .text),
                ]
            )
            .sqlStringValue,
            "CREATE TABLE IF NOT EXISTS test_table (column_a INTEGER, column_b TEXT);")
    }

    func testAlterTable() {
        XCTAssertEqual(
            SQLUpdate.alterTable(
                .init("test_table"), column: .init(name: .init("column_a"), valueType: .integer)
            ).sqlStringValue,
            "ALTER TABLE test_table ADD COLUMN column_a INTEGER;")
    }

    func testDropTable() {
        XCTAssertEqual(
            SQLUpdate.dropTable(.init("test_table")).sqlStringValue,
            "DROP TABLE IF EXISTS test_table;")
    }

    func testCreateIndex() {
        XCTAssertEqual(
            SQLUpdate.createIndex(
                .init("idx_name"), table: .init("table_name"),
                columnNames: [.init("attr_a"), .init("attr_b")]
            ).sqlStringValue,
            "CREATE INDEX IF NOT EXISTS idx_name ON table_name(attr_a, attr_b);")
    }

    func testDropIndex() {
        XCTAssertEqual(
            SQLUpdate.dropIndex(.init("idx_name")).sqlStringValue, "DROP INDEX IF EXISTS idx_name;"
        )
    }

    func testInsert() {
        XCTAssertEqual(
            SQLUpdate.insert(table: .init("aaa"), columnNames: [.init("abc"), .init("def")])
                .sqlStringValue,
            "INSERT INTO aaa(abc, def) VALUES(:abc, :def);")
        XCTAssertEqual(
            SQLUpdate.insert(table: .init("bbb")).sqlStringValue, "INSERT INTO bbb DEFAULT VALUES;"
        )
    }

    func testUpdate() {
        XCTAssertEqual(
            SQLUpdate.update(
                table: .init("ccc"), columnNames: [.init("qwe"), .init("rty")],
                where: .expression(.raw("(uio = :uio)"))
            ).sqlStringValue,
            "UPDATE ccc SET qwe = :qwe, rty = :rty WHERE (uio = :uio);")
    }

    func testDelete() {
        XCTAssertEqual(
            SQLUpdate.delete(table: .init("bbb"), where: .expression(.raw("xyz = :xyz")))
                .sqlStringValue,
            "DELETE FROM bbb WHERE xyz = :xyz;")
    }
}
