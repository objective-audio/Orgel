import XCTest

@testable import Orgel

final class ExecuteSqlTests: XCTestCase {
    private let uuid: UUID = .init()

    override func setUpWithError() throws {
        TestUtils.deleteFile(uuid: uuid)
    }

    override func tearDownWithError() throws {
        TestUtils.deleteFile(uuid: uuid)
    }

    func testTable() async throws {
        let executor = await TestUtils.makeAndOpenExecutor(uuid: uuid)

        let createSqlA = SQLUpdate.createTable(
            .init("test_table_a"), columns: [.init(name: .init("column_a"), valueType: .integer)])
        try await executor.executeUpdate(createSqlA).get()

        let createSqlB = SQLUpdate.createTable(
            .init("test_table_b"), columns: [.init(name: .init("column_b"), valueType: .text)])
        try await executor.executeUpdate(createSqlB).get()

        let tableAExists = await executor.tableExists(.init("test_table_a"))
        XCTAssertTrue(tableAExists)
        let tableBExists = await executor.tableExists(.init("test_table_b"))
        XCTAssertTrue(tableBExists)

        let schema1 = try await executor.tableSchema(.init("test_table_a")).get()
        XCTAssertEqual(schema1.count, 1)
        XCTAssertEqual(schema1[0][.name], .text("column_a"))

        let alterSql = SQLUpdate.alterTable(
            .init("test_table_a"), column: .init(name: .init("column_c"), valueType: .real))
        try await executor.executeUpdate(alterSql).get()

        let schema2 = try await executor.tableSchema(.init("test_table_a")).get()
        XCTAssertEqual(schema2.count, 2)
        XCTAssertEqual(schema2[0][.name], .text("column_a"))
        XCTAssertEqual(schema2[1][.name], .text("column_c"))

        let dropSql = SQLUpdate.dropTable(.init("test_table_b"))
        try await executor.executeUpdate(dropSql).get()

        await AssertTrueAsync(await executor.tableExists(.init("test_table_a")))
        await AssertFalseAsync(await executor.tableExists(.init("test_table_b")))

        await executor.close()
    }
}
