import Orgel
import SQLite3
import XCTest

final class SQLiteExecutorTests: XCTestCase {
    private let uuid: UUID = .init()

    override func setUpWithError() throws {
        TestUtils.deleteFile(uuid: uuid)
    }

    override func tearDownWithError() throws {
        TestUtils.deleteFile(uuid: uuid)
    }

    func testLibVersion() throws {
        XCTAssertFalse(SQLiteExecutor.libVersion.isEmpty)
    }

    func testThreadSafe() throws {
        XCTAssertTrue(SQLiteExecutor.isThreadSafe)
    }

    func testInit() async throws {
        let url = TestUtils.databaseUrl(uuid: uuid)
        let executor = SQLiteExecutor(url: url)

        await AssertEqualAsync(await executor.url, url)
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: TestUtils.databaseUrl(uuid: uuid).path))
    }

    func testOpenAndClose() async throws {
        let url = TestUtils.databaseUrl(uuid: uuid)
        let executor = SQLiteExecutor(url: url)

        await AssertFalseAsync(await executor.goodConnection)

        await AssertTrueAsync(await executor.open())

        await AssertTrueAsync(await executor.hasSqliteHandle)
        await AssertTrueAsync(await executor.goodConnection)
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: TestUtils.databaseUrl(uuid: uuid).path))

        await executor.close()

        await AssertFalseAsync(await executor.hasSqliteHandle)
        await AssertFalseAsync(await executor.goodConnection)
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: TestUtils.databaseUrl(uuid: uuid).path))
    }

    func testCreateTable() async throws {
        let executor = await TestUtils.makeAndOpenExecutor(uuid: uuid)

        try await executor.executeUpdate(
            .raw("create table test_table_1 (column_a, column_b);")
        )
        try await executor.executeUpdate(
            .raw("create table test_table_2 (column_c, column_d);")
        )

        await AssertTrueAsync(await executor.tableExists(.init("test_table_1")))
        await AssertTrueAsync(
            await executor.columnExists(columnName: "column_a", tableName: "test_table_1"))
        await AssertTrueAsync(
            await executor.columnExists(columnName: "column_b", tableName: "test_table_1"))
        await AssertTrueAsync(await executor.tableExists(.init("test_table_2")))
        await AssertTrueAsync(
            await executor.columnExists(columnName: "column_c", tableName: "test_table_2"))
        await AssertTrueAsync(
            await executor.columnExists(columnName: "column_d", tableName: "test_table_2"))

        await executor.close()
    }

    func testExecuteUpdate() async throws {
        let executor = await TestUtils.makeAndOpenExecutor(uuid: uuid)

        try await executor.createTable(
            .init("test_table"),
            columns: [
                .init(name: .init("column_a"), valueType: .integer),
                .init(name: .init("column_b"), valueType: .text),
            ]
        )

        let insertParams: [SQLParameter.Name: SQLValue] = [
            .init("column_a"): .text("value_a"), .init("column_b"): .text("value_b"),
        ]
        try await executor.executeUpdate(
            .raw("insert into test_table(column_a, column_b) values(:column_a, :column_b)"),
            parameters: insertParams
        )

        try await executor.executeQuery(
            .raw("select * from test_table"),
            iteration: { iterator in
                XCTAssertTrue(iterator.next())

                XCTAssertEqual(iterator.columnValue(forName: "column_a"), .text("value_a"))
                XCTAssertEqual(iterator.columnValue(forName: "column_b"), .text("value_b"))

                XCTAssertFalse(iterator.next())
            }
        )

        let updateParams: [SQLParameter.Name: SQLValue] = [
            .init("column_a"): .text("value_a_2"), .init("column_b"): .text("value_b_2"),
        ]
        try await executor.executeUpdate(
            .raw("update test_table set column_a = :column_a, column_b = :column_b"),
            parameters: updateParams
        )

        try await executor.executeQuery(
            .raw("select * from test_table"),
            iteration: { iterator in
                XCTAssertTrue(iterator.next())

                XCTAssertEqual(iterator.columnValue(forName: "column_a"), .text("value_a_2"))
                XCTAssertEqual(iterator.columnValue(forName: "column_b"), .text("value_b_2"))

                XCTAssertFalse(iterator.next())
            }
        )

        await executor.close()
    }

    func testExecuteQuery() async throws {
        let executor = await TestUtils.makeAndOpenExecutor(uuid: uuid)

        try await executor.createTable(
            .init("test_table"), columns: [.init(name: .init("column_a"), valueType: .integer)]
        )
        try await executor.executeUpdate(
            .raw("insert into test_table(column_a) values(:column_a)"),
            parameters: [.init("column_a"): .text("value_a")]
        )
        try await executor.executeUpdate(
            .raw("insert into test_table(column_a) values(:column_a)"),
            parameters: [.init("column_a"): .text("hoge_a")]
        )

        let columnAValue = try await executor.executeQuery(
            .raw("select * from test_table where column_a = :column_a"),
            parameters: [.init("column_a"): .text("value_a")],
            iteration: { iterator in
                XCTAssertTrue(iterator.next())

                let columnAValue = iterator.columnValue(forName: "column_a")

                XCTAssertFalse(iterator.next())

                return columnAValue
            }
        )

        XCTAssertEqual(columnAValue, .text("value_a"))

        await executor.close()
    }

    func testGetError() async throws {
        let executor = await TestUtils.makeAndOpenExecutor(uuid: uuid)

        await AssertFalseAsync(await executor.hadError)
        await AssertEqualAsync(await executor.lastErrorCode, SQLITE_OK)
        await AssertEqualAsync(await executor.lastErrorMessage, "not an error")

        await AssertThrowsErrorAsync(try await executor.executeUpdate(.raw("hoge")))

        await AssertTrueAsync(await executor.hadError)
        await AssertNotEqualAsync(await executor.lastErrorCode, SQLITE_OK)
        await AssertNotEqualAsync(await executor.lastErrorMessage, "not an error")

        await executor.close()
    }

    func testForeignKey() async throws {
        let executor = await TestUtils.makeAndOpenExecutor(uuid: uuid)

        try await executor.beginTransaction()

        try await executor.executeUpdate(
            .raw("create table idmaster (id integer primary key autoincrement, name text);")
        )
        try await executor.executeUpdate(.raw("insert into idmaster values (null, 'A');"))
        try await executor.executeUpdate(
            .raw(
                "create table address (id integer, address text, foreign key(id) references idmaster(id) on delete cascade);"
            )
        )
        try await executor.executeUpdate(.raw("insert into address values (1, 'addressA');"))
        await AssertThrowsErrorAsync(
            try await executor.executeUpdate(
                .raw("insert into address values (2, 'addressB');")
            ))

        try await executor.commit()

        try await executor.executeQuery(
            .raw("select * from idmaster;"),
            iteration: { iterator in
                XCTAssertTrue(iterator.next())
                XCTAssertFalse(iterator.next())
            }
        )

        try await executor.executeQuery(
            .raw("select * from address;"),
            iteration: { iterator in
                XCTAssertTrue(iterator.next())
                XCTAssertFalse(iterator.next())
            }
        )

        try await executor.executeUpdate(.raw("delete from idmaster"))

        try await executor.executeQuery(
            .raw("select * from idmaster;"),
            iteration: { iterator in
                XCTAssertFalse(iterator.next())
            }
        )

        try await executor.executeQuery(
            .raw("select * from address;"),
            iteration: { iterator in
                XCTAssertFalse(iterator.next())
            }
        )

        await executor.close()
    }

    func testIntegrityCheck() async {
        let executor = await TestUtils.makeAndOpenExecutor(uuid: uuid)

        await AssertTrueAsync(await executor.integrityCheck)

        await executor.close()
    }
}
