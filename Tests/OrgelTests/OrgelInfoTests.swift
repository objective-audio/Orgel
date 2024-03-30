import XCTest

@testable import Orgel

final class DatabaseInfoTests: XCTestCase {
    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
    }

    func testInit() throws {
        let version = try Version("1.0.0")
        let info = OrgelInfo(version: version, currentSaveId: 1, lastSaveId: 3)

        XCTAssertEqual(info.version.stringValue, "1.0.0")
        XCTAssertEqual(info.currentSaveId, 1)
        XCTAssertEqual(info.lastSaveId, 3)
        XCTAssertEqual(info.currentSaveIdValue, .integer(1))
        XCTAssertEqual(info.lastSaveIdValue, .integer(3))
        XCTAssertEqual(info.nextSaveIdValue, .integer(2))
    }

    func testInitWithValues() throws {
        let values: [SQLColumn.Name: SQLValue] = [
            .version: .text("1.2.3"),
            .currentSaveId: .integer(10),
            .lastSaveId: .integer(20),
        ]

        let info = try OrgelInfo(values: values)

        XCTAssertEqual(info.version.stringValue, "1.2.3")
        XCTAssertEqual(info.currentSaveId, 10)
        XCTAssertEqual(info.lastSaveId, 20)
    }

    func testSqlForCreate() throws {
        XCTAssertEqual(
            OrgelInfo.sqlForCreate.sqlStringValue,
            "CREATE TABLE IF NOT EXISTS db_info (version TEXT, cur_save_id INTEGER, last_save_id INTEGER);"
        )
    }

    func testSqlForInsert() throws {
        XCTAssertEqual(
            OrgelInfo.sqlForInsert.sqlStringValue,
            "INSERT INTO db_info(version, cur_save_id, last_save_id) VALUES(:version, :cur_save_id, :last_save_id);"
        )
    }

    func testSqlForUpdateVersion() throws {
        XCTAssertEqual(
            OrgelInfo.sqlForUpdateVersion.sqlStringValue,
            "UPDATE db_info SET version = :version;")
    }

    func testSqlForUpdateSaveIds() throws {
        XCTAssertEqual(
            OrgelInfo.sqlForUpdateSaveIds.sqlStringValue,
            "UPDATE db_info SET cur_save_id = :cur_save_id, last_save_id = :last_save_id;")
    }

    func testSqlForUpdateCurrentSaveId() throws {
        XCTAssertEqual(
            OrgelInfo.sqlForUpdateCurrentSaveId.sqlStringValue,
            "UPDATE db_info SET cur_save_id = :cur_save_id;"
        )
    }
}
