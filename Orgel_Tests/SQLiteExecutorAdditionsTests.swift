import Orgel
import XCTest

final class SQLiteExecutorAdditionsTests: XCTestCase {
    private let uuid: UUID = .init()

    override func setUpWithError() throws {
        TestUtils.deleteFile(uuid: uuid)
    }

    override func tearDownWithError() throws {
        TestUtils.deleteFile(uuid: uuid)
    }

    func testTable() async throws {
        let executor = await TestUtils.makeAndOpenExecutor(uuid: uuid)

        let tableA = SQLTable("test_table_a")
        let tableB = SQLTable("test_table_b")
        let columnA = SQLColumn(name: .init("column_a"), valueType: .integer)
        let columnB = SQLColumn(name: .init("column_b"), valueType: .text)
        let columnC = SQLColumn(name: .init("column_c"), valueType: .real)

        try await executor.createTable(tableA, columns: [columnA]).get()
        await AssertTrueAsync(await executor.tableExists(tableA))

        try await executor.createTable(tableB, columns: [columnB]).get()
        await AssertTrueAsync(await executor.tableExists(tableB))

        let schema1 = try await executor.tableSchema(tableA).get()

        XCTAssertEqual(schema1.count, 1)
        XCTAssertEqual(schema1[0][.name], .text("column_a"))

        try await executor.alterTable(tableA, column: columnC).get()

        let schema2 = try await executor.tableSchema(tableA).get()

        XCTAssertEqual(schema2.count, 2)
        XCTAssertEqual(schema2[0][.name], .text("column_a"))
        XCTAssertEqual(schema2[1][.name], .text("column_c"))

        try await executor.dropTable(tableB).get()

        await AssertTrueAsync(await executor.tableExists(tableA))
        await AssertFalseAsync(await executor.tableExists(tableB))

        await executor.close()
    }

    func testTransactionCommit() async throws {
        let executor = await TestUtils.makeAndOpenExecutor(uuid: uuid)

        try await executor.createTable(
            .init("test_table"), columns: [.init(name: .init("test_column"), valueType: .integer)]
        ).get()
        try await executor.executeUpdate(
            .raw("insert into test_table(test_column) values('value1')")
        )
        .get()

        try await executor.executeQuery(
            .raw("select * from test_table"),
            iteration: { iterator in
                XCTAssertTrue(iterator.next())
                XCTAssertFalse(iterator.next())
            }
        ).get()

        try await executor.beginTransaction().get()
        try await executor.executeUpdate(
            .raw("insert into test_table(test_column) values('value2')")
        )
        .get()
        try await executor.executeUpdate(
            .raw("insert into test_table(test_column) values('value3')")
        )
        .get()
        try await executor.commit().get()

        try await executor.executeQuery(
            .raw("select * from test_table"),
            iteration: { iterator in
                XCTAssertTrue(iterator.next())
                XCTAssertTrue(iterator.next())
                XCTAssertTrue(iterator.next())
                XCTAssertFalse(iterator.next())
            }
        ).get()

        await executor.close()
    }

    func testTransactionRollback() async throws {
        let executor = await TestUtils.makeAndOpenExecutor(uuid: uuid)

        try await executor.createTable(
            .init("test_table"), columns: [.init(name: .init("test_column"), valueType: .integer)]
        ).get()
        try await executor.executeUpdate(
            .raw("insert into test_table(test_column) values('value1')")
        )
        .get()

        try await executor.executeQuery(
            .raw("select * from test_table"),
            iteration: { iterator in
                XCTAssertTrue(iterator.next())
                XCTAssertFalse(iterator.next())
            }
        ).get()

        try await executor.beginTransaction().get()
        try await executor.executeUpdate(
            .raw("insert into test_table(test_column) values('value2')")
        )
        .get()
        try await executor.executeUpdate(
            .raw("insert into test_table(test_column) values('value3')")
        )
        .get()
        try await executor.rollback().get()

        try await executor.executeQuery(
            .raw("select * from test_table"),
            iteration: { iterator in
                XCTAssertTrue(iterator.next())
                XCTAssertFalse(iterator.next())
            }
        ).get()

        await executor.close()
    }

    func testTableExists() async throws {
        let executor = await TestUtils.makeAndOpenExecutor(uuid: uuid)

        try await executor.createTable(
            .init("test_table"), columns: [.init(name: .init("column"), valueType: .integer)]
        ).get()

        await AssertTrueAsync(await executor.tableExists(.init("test_table")))
        await AssertFalseAsync(await executor.tableExists(.init("hoge")))

        await executor.close()
    }

    func testIndexExists() async throws {
        let executor = await TestUtils.makeAndOpenExecutor(uuid: uuid)

        try await executor.createTable(
            .init("test_table"), columns: [.init(name: .init("column"), valueType: .integer)]
        ).get()

        await AssertFalseAsync(await executor.indexExists(.init("test_index")))

        try await executor.createIndex(
            .init("test_index"), table: .init("test_table"), columnNames: [.init("column")]
        ).get()

        await AssertTrueAsync(await executor.indexExists(.init("test_index")))
        await AssertFalseAsync(await executor.indexExists(.init("hoge")))

        try await executor.dropIndex(.init("test_index")).get()

        await AssertFalseAsync(await executor.indexExists(.init("test_index")))

        await executor.close()
    }

    func testColumnExists() async throws {
        let executor = await TestUtils.makeAndOpenExecutor(uuid: uuid)

        try await executor.createTable(
            .init("test_table"),
            columns: [
                .init(name: .init("column_a"), valueType: .integer),
                .init(name: .init("column_b"), valueType: .text),
            ]
        )
        .get()

        await AssertTrueAsync(
            await executor.columnExists(columnName: "column_a", tableName: "test_table"))
        await AssertTrueAsync(
            await executor.columnExists(columnName: "column_b", tableName: "test_table"))

        await AssertFalseAsync(
            await executor.columnExists(columnName: "column_a", tableName: "hoge"))
        await AssertFalseAsync(
            await executor.columnExists(columnName: "hoge", tableName: "test_table"))

        await executor.close()
    }

    func testSchema() async throws {
        let executor = await TestUtils.makeAndOpenExecutor(uuid: uuid)

        let sql1 = "CREATE TABLE test_table_1 (test_column)"
        try await executor.executeUpdate(.raw(sql1)).get()

        let sql2 = "CREATE TABLE test_table_2 (test_column)"
        try await executor.executeUpdate(.raw(sql2)).get()

        let schema = try await executor.schema().get()

        XCTAssertEqual(schema.count, 2)

        XCTAssertEqual(schema[0][.System.sql], .text(sql1))
        XCTAssertEqual(schema[0][.System.tblName], .text("test_table_1"))
        XCTAssertEqual(schema[0][.System.name], .text("test_table_1"))
        XCTAssertNotNil(schema[0][.System.rootpage])
        XCTAssertEqual(schema[0][.System.type], .text("table"))

        XCTAssertEqual(schema[1][.System.sql], .text(sql2))
        XCTAssertEqual(schema[1][.System.tblName], .text("test_table_2"))
        XCTAssertEqual(schema[1][.System.name], .text("test_table_2"))
        XCTAssertNotNil(schema[1][.System.rootpage])
        XCTAssertEqual(schema[1][.System.type], .text("table"))

        await executor.close()
    }

    func testTableSchema() async throws {
        let executor = await TestUtils.makeAndOpenExecutor(uuid: uuid)

        try await executor.createTable(
            .init("test_table"),
            columns: [
                .init(name: .init("column_a"), valueType: .integer),
                .init(name: .init("column_b"), valueType: .text),
            ]
        )
        .get()

        let schema = try await executor.tableSchema(.init("test_table")).get()

        XCTAssertEqual(schema.count, 2)
        XCTAssertNotNil(schema[0][.System.pk])
        XCTAssertNotNil(schema[0][.System.dfltValue])
        XCTAssertNotNil(schema[0][.System.type])
        XCTAssertNotNil(schema[0][.System.notnull])
        XCTAssertNotNil(schema[0][.System.name])
        XCTAssertNotNil(schema[0][.System.cid])

        XCTAssertEqual(schema[0][.name], .text("column_a"))
        XCTAssertEqual(schema[1][.name], .text("column_b"))

        await executor.close()
    }

    func testIndexSchema() async throws {
        let executor = await TestUtils.makeAndOpenExecutor(uuid: uuid)

        try await executor.createTable(
            .init("test_table"),
            columns: [
                .init(name: .init("column_a"), valueType: .integer),
                .init(name: .init("column_b"), valueType: .text),
            ]
        )
        .get()
        try await executor.createIndex(
            .init("test_index"), table: .init("test_table"), columnNames: [.init("column_a")]
        ).get()

        let schema = try await executor.indexSchema(.init("test_index")).get()

        XCTAssertEqual(schema[.System.type], .text("index"))
        XCTAssertEqual(schema[.System.name], .text("test_index"))
        XCTAssertEqual(schema[.System.tblName], .text("test_table"))

        await executor.close()
    }

    func testSelect() async throws {
        let executor = await TestUtils.makeAndOpenExecutor(uuid: uuid)

        let table = SQLTable("table_a")
        let columnNameA = SQLColumn.Name("column_a")
        let parameterNameA = SQLParameter.Name("column_a")
        let columnNameB = SQLColumn.Name("column_b")
        let columnA = SQLColumn(name: columnNameA, valueType: .integer)
        let columnB = SQLColumn(name: columnNameB, valueType: .text)

        try await executor.createTable(table, columns: [columnA, columnB]).get()

        let params1: [SQLParameter.Name: SQLValue] = [
            .init("column_a"): .text("value_a_1"), .init("column_b"): .text("value_b_1"),
        ]
        try await executor.executeUpdate(
            .insert(table: table, columnNames: [columnNameA, columnNameB]), parameters: params1
        ).get()

        let params2: [SQLParameter.Name: SQLValue] = [
            .init("column_a"): .text("value_a_2"), .init("column_b"): .text("value_b_2"),
        ]
        try await executor.executeUpdate(
            .insert(table: table, columnNames: [columnNameA, columnNameB]), parameters: params2
        ).get()

        let selected = try await executor.select(
            .init(
                table: table, field: .columns([columnNameA, columnNameB]),
                where: .expression(.compare(columnNameA, .equal, .name(parameterNameA))),
                parameters: [parameterNameA: .text("value_a_2")])
        ).get()

        XCTAssertEqual(selected.count, 1)

        await executor.close()
    }
}
