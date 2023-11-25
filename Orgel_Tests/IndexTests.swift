import XCTest

@testable import Orgel

final class IndexTests: XCTestCase {
    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
    }

    func testInitSuccess() throws {
        let index = try Index(
            name: .init("test_name"), entity: .init("test_table_name"),
            attributes: [.init("test_attr_name_0"), .init("test_attr_name_1")])

        XCTAssertEqual(index.name, .init("test_name"))
        XCTAssertEqual(index.entity, .init("test_table_name"))
        XCTAssertEqual(index.attributes.count, 2)
        XCTAssertEqual(index.attributes[0], .init("test_attr_name_0"))
        XCTAssertEqual(index.attributes[1], .init("test_attr_name_1"))
    }

    func testInitFailure() throws {
        XCTAssertThrowsError(
            try Index(
                name: .init(""), entity: .init("test_table_name"),
                attributes: [.init("test_attr_name")]))
        XCTAssertThrowsError(
            try Index(
                name: .init("test_name"), entity: .init(""), attributes: [.init("test_attr_name")]))
        XCTAssertThrowsError(
            try Index(name: .init("test_name"), entity: .init("test_table_name"), attributes: []))
        XCTAssertThrowsError(
            try Index(
                name: .init("test_name"), entity: .init("test_table_name"), attributes: [.init("")])
        )
    }

    func testSqlForCreate() throws {
        let index = try Index(
            name: .init("idx_name"), entity: .init("tbl_name"),
            attributes: [.init("attr_0"), .init("attr_1")])
        XCTAssertEqual(
            index.sqlForCreate.sqlStringValue,
            "CREATE INDEX IF NOT EXISTS idx_name ON tbl_name(attr_0, attr_1);")
    }
}
