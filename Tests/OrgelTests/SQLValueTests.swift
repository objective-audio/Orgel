import Orgel
import XCTest

final class SQLValueTests: XCTestCase {
    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
    }

    func testIntegerSql() throws {
        XCTAssertEqual(SQLValue.integer(0).sqlStringValue, "0")
        XCTAssertEqual(SQLValue.integer(1).sqlStringValue, "1")
        XCTAssertEqual(SQLValue.integer(-1).sqlStringValue, "-1")
    }

    func testRealSql() throws {
        XCTAssertEqual(SQLValue.real(0.0).sqlStringValue, "0.0")
        XCTAssertEqual(SQLValue.real(1.0).sqlStringValue, "1.0")
        XCTAssertEqual(SQLValue.real(-1.0).sqlStringValue, "-1.0")
    }

    func testTextSql() throws {
        XCTAssertEqual(SQLValue.text("test_text").sqlStringValue, "'test_text'")
    }

    func testNullSql() throws {
        XCTAssertEqual(SQLValue.null.sqlStringValue, "null")
    }

    func testEquals() throws {
        XCTAssertEqual(SQLValue.integer(0), SQLValue.integer(0))
        XCTAssertNotEqual(SQLValue.integer(0), SQLValue.integer(1))

        XCTAssertEqual(SQLValue.real(1.0), SQLValue.real(1.0))
        XCTAssertNotEqual(SQLValue.real(1.0), SQLValue.real(2.0))
    }

    func testIntegerValue() throws {
        XCTAssertEqual(SQLValue.integer(1).integerValue, 1)

        XCTAssertNil(SQLValue.real(1.0).integerValue)
        XCTAssertNil(SQLValue.text("1").integerValue)
        XCTAssertNil(SQLValue.blob(Data()).integerValue)
        XCTAssertNil(SQLValue.null.integerValue)
    }

    func testRealValue() throws {
        XCTAssertEqual(SQLValue.real(1.0).realValue, 1.0)

        XCTAssertNil(SQLValue.integer(1).realValue)
        XCTAssertNil(SQLValue.text("1").realValue)
        XCTAssertNil(SQLValue.blob(Data()).realValue)
        XCTAssertNil(SQLValue.null.realValue)
    }

    func testTextValue() throws {
        XCTAssertEqual(SQLValue.text("1").textValue, "1")

        XCTAssertNil(SQLValue.integer(1).textValue)
        XCTAssertNil(SQLValue.real(1.0).textValue)
        XCTAssertNil(SQLValue.blob(Data()).textValue)
        XCTAssertNil(SQLValue.null.textValue)
    }

    func testBlobValue() throws {
        let data = Data(repeating: 1, count: 1)

        XCTAssertEqual(SQLValue.blob(data).blobValue, data)

        XCTAssertNil(SQLValue.integer(1).blobValue)
        XCTAssertNil(SQLValue.real(1.0).blobValue)
        XCTAssertNil(SQLValue.text("1").blobValue)
        XCTAssertNil(SQLValue.null.blobValue)
    }

    func testIsNull() throws {
        XCTAssertTrue(SQLValue.null.isNull)

        XCTAssertFalse(SQLValue.integer(1).isNull)
        XCTAssertFalse(SQLValue.real(1.0).isNull)
        XCTAssertFalse(SQLValue.text("1").isNull)
        XCTAssertFalse(SQLValue.blob(Data()).isNull)
    }
}
