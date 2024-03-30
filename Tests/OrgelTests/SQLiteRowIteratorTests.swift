import Orgel
import SQLite3
import XCTest

final class SQLiteIteratorTests: XCTestCase {
    private let uuid: UUID = .init()

    override func setUpWithError() throws {
        TestUtils.deleteFile(uuid: uuid)
    }

    override func tearDownWithError() throws {
        TestUtils.deleteFile(uuid: uuid)
    }

    func testColumn() async throws {
        let executor = await TestUtils.makeAndOpenExecutor(uuid: uuid)

        try await executor.executeUpdate(.raw("create table test_table (column_a, column_b);"))

        let params: [SQLParameter.Name: SQLValue] = [
            .init("column_a"): .text("value_a"), .init("column_b"): .null,
        ]
        try await executor.executeUpdate(
            .raw("insert into test_table(column_a, column_b) values(:column_a, :column_b)"),
            parameters: params
        )

        try await executor.executeQuery(
            .raw("select column_a, column_b from test_table"),
            iteration: { iterator in
                XCTAssertTrue(iterator.next())

                XCTAssertEqual(iterator.columnCount, 2)
                XCTAssertEqual(iterator.columnIndex(forName: "column_a"), 0)
                XCTAssertEqual(iterator.columnIndex(forName: "column_b"), 1)
                XCTAssertEqual(iterator.columnName(forIndex: 0), "column_a")
                XCTAssertEqual(iterator.columnName(forIndex: 1), "column_b")

                XCTAssertFalse(iterator.columnIsNull(forIndex: 0))
                XCTAssertTrue(iterator.columnIsNull(forIndex: 1))
                XCTAssertFalse(iterator.columnIsNull(forName: "column_a"))
                XCTAssertTrue(iterator.columnIsNull(forName: "column_b"))
            }
        )

        await executor.close()
    }

    func testHasRow() async throws {
        let executor = await TestUtils.makeAndOpenExecutor(uuid: uuid)

        try await executor.executeUpdate(.raw("create table test_table (column_a, column_b);"))

        let params: [SQLParameter.Name: SQLValue] = [
            .init("column_a"): .text("value_a"), .init("column_b"): .null,
        ]

        try await executor.executeUpdate(
            .raw("insert into test_table(column_a, column_b) values(:column_a, :column_b)"),
            parameters: params
        )

        try await executor.executeQuery(
            .raw("select column_a, column_b from test_table"),
            iteration: { iterator in
                XCTAssertFalse(iterator.hasRow)

                XCTAssertTrue(iterator.next())

                XCTAssertTrue(iterator.hasRow)

                XCTAssertFalse(iterator.next())

                XCTAssertFalse(iterator.hasRow)
            }
        )

        await executor.close()
    }

    func testColumnValue() async throws {
        let executor = await TestUtils.makeAndOpenExecutor(uuid: uuid)

        try await executor.executeUpdate(
            .raw(
                "create table test_table (int_column, float_column, string_column, data_column, null_column);"
            )
        )

        let data = Data([UInt8]([0, 1, 2, 3]))

        let params: [SQLParameter.Name: SQLValue] = [
            .init("int_column"): .integer(1), .init("float_column"): .real(2.0),
            .init("string_column"): .text("string_value"), .init("data_column"): .blob(data),
            .init("null_column"): .null,
        ]

        try await executor.executeUpdate(
            .raw(
                "insert into test_table(int_column, float_column, string_column, data_column, null_column) values(:int_column, :float_column, :string_column, :data_column, :null_column)"
            ),
            parameters: params
        )

        try await executor.executeQuery(
            .raw("select * from test_table"),
            iteration: { iterator in
                XCTAssertTrue(iterator.next())

                let intValue = iterator.columnValue(forName: "int_column")
                let floatValue = iterator.columnValue(forName: "float_column")
                let stringValue = iterator.columnValue(forName: "string_column")
                let dataValue = iterator.columnValue(forName: "data_column")
                let nullValue = iterator.columnValue(forName: "null_column")

                XCTAssertEqual(intValue, .integer(1))
                XCTAssertEqual(floatValue, .real(2.0))
                XCTAssertEqual(stringValue, .text("string_value"))
                XCTAssertEqual(nullValue, .null)

                let resultData = try XCTUnwrap(dataValue.blobValue)

                XCTAssertEqual(resultData.count, 4)

                resultData.withUnsafeBytes { ptr in
                    ptr.withMemoryRebound(to: UInt8.self) { buffer in
                        XCTAssertEqual(buffer[0], 0)
                        XCTAssertEqual(buffer[1], 1)
                        XCTAssertEqual(buffer[2], 2)
                        XCTAssertEqual(buffer[3], 3)
                    }
                }

                XCTAssertFalse(iterator.next())
            }
        )

        await executor.close()
    }

    func testValues() async throws {
        let executor = await TestUtils.makeAndOpenExecutor(uuid: uuid)

        try await executor.executeUpdate(
            .raw(
                "create table test_table (int_column, float_column, string_column, data_column, null_column);"
            )
        )

        let data = Data([UInt8]([0, 1, 2, 3]))

        let params: [SQLParameter.Name: SQLValue] = [
            .init("int_column"): .integer(1), .init("float_column"): .real(2.0),
            .init("string_column"): .text("string_value"), .init("data_column"): .blob(data),
            .init("null_column"): .null,
        ]

        try await executor.executeUpdate(
            .raw(
                "insert into test_table(int_column, float_column, string_column, data_column, null_column) values(:int_column, :float_column, :string_column, :data_column, :null_column)"
            ),
            parameters: params
        )

        try await executor.executeQuery(
            .raw("select * from test_table"),
            iteration: { iterator in
                XCTAssertTrue(iterator.next())

                let values = iterator.values

                XCTAssertEqual(values[.init("int_column")], .integer(1))
                XCTAssertEqual(values[.init("float_column")], .real(2.0))
                XCTAssertEqual(values[.init("string_column")], .text("string_value"))
                XCTAssertEqual(values[.init("null_column")], .null)

                let resultData = try XCTUnwrap(values[.init("data_column")]?.blobValue)

                XCTAssertEqual(resultData.count, 4)

                resultData.withUnsafeBytes { ptr in
                    ptr.withMemoryRebound(to: UInt8.self) { buffer in
                        XCTAssertEqual(buffer[0], 0)
                        XCTAssertEqual(buffer[1], 1)
                        XCTAssertEqual(buffer[2], 2)
                        XCTAssertEqual(buffer[3], 3)
                    }
                }

                XCTAssertFalse(iterator.next())
            }
        )

        await executor.close()
    }
}
