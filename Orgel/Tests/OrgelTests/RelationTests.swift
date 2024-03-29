import XCTest

@testable import Orgel

final class RelationTests: XCTestCase {
    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
    }

    func testInitSuccess() throws {
        let relation = try Relation(
            name: .init("test_name"), source: .init("test_entity"), target: .init("test_target"),
            many: true)

        XCTAssertEqual(relation.source, .init("test_entity"))
        XCTAssertEqual(relation.name, .init("test_name"))
        XCTAssertEqual(relation.target, .init("test_target"))
        XCTAssertTrue(relation.many)
    }

    func testInitFailure() throws {
        XCTAssertThrowsError(
            try Relation(
                name: .init(""), source: .init("test_entity"), target: .init("test_target")))
        XCTAssertThrowsError(
            try Relation(name: .init("test_name"), source: .init(""), target: .init("test_target")))
        XCTAssertThrowsError(
            try Relation(name: .init("test_name"), source: .init("test_entity"), target: .init("")))
    }

    func testTableName() throws {
        let relation = try Relation(
            name: .init("test_name"), source: .init("test_entity"), target: .init("test_target"),
            many: true)

        XCTAssertEqual(relation.table.sqlStringValue, "rel_test_entity_test_name")
    }

    func testSqlForCreate() throws {
        let relation = try Relation(
            name: .init("b"), source: .init("a"), target: .init("c"), many: true)

        XCTAssertEqual(
            relation.sqlForCreate.sqlStringValue,
            "CREATE TABLE IF NOT EXISTS rel_a_b (pk_id INTEGER PRIMARY KEY AUTOINCREMENT, src_pk_id INTEGER, src_obj_id INTEGER, tgt_obj_id INTEGER, save_id INTEGER);"
        )
    }

    func testSqlForInsert() throws {
        let relation = try Relation(
            name: .init("b"), source: .init("a"), target: .init("c"), many: true)

        XCTAssertEqual(
            relation.sqlForInsert.sqlStringValue,
            "INSERT INTO rel_a_b(src_pk_id, src_obj_id, tgt_obj_id, save_id) VALUES(:src_pk_id, :src_obj_id, :tgt_obj_id, :save_id);"
        )
    }
}
