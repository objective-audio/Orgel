import XCTest

@testable import Orgel

final class ObjectTests: XCTestCase {
    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
    }

    func testCustomTableName() throws {
        @OrgelObject
        struct Object: ObjectCodable {
            struct Attributes: AttributesCodable {}
            struct Relations: RelationsCodable {}

            static var tableName: String { "custom_table_name" }
        }

        XCTAssertEqual(Object.tableName, "custom_table_name")
        XCTAssertEqual(Object.entity.name, .init("custom_table_name"))
    }

    func testSetRelations() throws {
        let idA: ObjectA.Id = .init(rawId: .stable(.init(1)))
        let idB0: ObjectB.Id = .init(rawId: .stable(.init(10)))
        let idB1: ObjectB.Id = .init(rawId: .stable(.init(11)))

        var objectA = ObjectA(
            id: idA, attributes: .init(age: 0), relations: .init())

        XCTAssertEqual(objectA.relations.children, [])
        XCTAssertNil(objectA.relations.friend)

        let objectB0 = ObjectB(
            id: idB0, attributes: .init(fullname: "fullname-b0"),
            relations: .init())
        let objectB1 = ObjectB(
            id: idB1, attributes: .init(fullname: "fullname-b1"),
            relations: .init())

        objectA.setRelations([objectB0, objectB1], forKeyPath: \.children)

        XCTAssertEqual(
            objectA.relations.children,
            [.init(rawId: .stable(.init(10))), .init(rawId: .stable(.init(11)))])
        XCTAssertNil(objectA.relations.friend)
    }

    func testSetRelation() throws {
        let idA: ObjectA.Id = .init(rawId: .stable(.init(1)))
        let idC: ObjectC.Id = .init(rawId: .stable(.init(100)))

        var objectA = ObjectA(
            id: idA, attributes: .init(age: 0), relations: .init())

        XCTAssertEqual(objectA.relations.children, [])
        XCTAssertNil(objectA.relations.friend)

        let objectC = ObjectC(
            id: idC, attributes: .init(nickname: "nickname-c"),
            relations: .init())

        objectA.setRelation(objectC, forKeyPath: \.friend)

        XCTAssertEqual(objectA.relations.children, [])
        XCTAssertEqual(objectA.relations.friend, .init(rawId: .stable(.init(100))))
    }

    func testAppendRelation() throws {
        let idA: ObjectA.Id = .init(rawId: .stable(.init(1)))
        let idB0: ObjectB.Id = .init(rawId: .stable(.init(10)))
        let idB1: ObjectB.Id = .init(rawId: .stable(.init(11)))

        var objectA = ObjectA(
            id: idA, attributes: .init(age: 0), relations: .init())

        XCTAssertEqual(objectA.relations.children, [])

        let objectB0 = ObjectB(
            id: idB0, attributes: .init(fullname: "fullname-b0"),
            relations: .init())
        let objectB1 = ObjectB(
            id: idB1, attributes: .init(fullname: "fullname-b1"),
            relations: .init())

        objectA.appendRelation(objectB0, forKeyPath: \.children)

        XCTAssertEqual(objectA.relations.children, [.init(rawId: .stable(.init(10)))])

        objectA.appendRelation(objectB1, forKeyPath: \.children)

        XCTAssertEqual(
            objectA.relations.children,
            [.init(rawId: .stable(.init(10))), .init(rawId: .stable(.init(11)))])
    }

    func testInsertRelation() throws {
        let idA: ObjectA.Id = .init(rawId: .stable(.init(1)))
        let idB0: ObjectB.Id = .init(rawId: .stable(.init(10)))
        let idB1: ObjectB.Id = .init(rawId: .stable(.init(11)))
        let idB2: ObjectB.Id = .init(rawId: .stable(.init(12)))

        var objectA = ObjectA(
            id: idA, attributes: .init(age: 0), relations: .init())

        XCTAssertEqual(objectA.relations.children, [])

        let objectB0 = ObjectB(
            id: idB0, attributes: .init(fullname: "fullname-b0"),
            relations: .init())
        let objectB1 = ObjectB(
            id: idB1, attributes: .init(fullname: "fullname-b1"),
            relations: .init())
        let objectB2 = ObjectB(
            id: idB2, attributes: .init(fullname: "fullname-b2"),
            relations: .init())

        objectA.insertRelation(objectB2, at: 0, forKeyPath: \.children)

        XCTAssertEqual(objectA.relations.children, [.init(rawId: .stable(.init(12)))])

        objectA.insertRelation(objectB0, at: 0, forKeyPath: \.children)

        XCTAssertEqual(
            objectA.relations.children,
            [.init(rawId: .stable(.init(10))), .init(rawId: .stable(.init(12)))])

        objectA.insertRelation(objectB1, at: 1, forKeyPath: \.children)

        XCTAssertEqual(
            objectA.relations.children,
            [
                .init(rawId: .stable(.init(10))), .init(rawId: .stable(.init(11))),
                .init(rawId: .stable(.init(12))),
            ])
    }
}
