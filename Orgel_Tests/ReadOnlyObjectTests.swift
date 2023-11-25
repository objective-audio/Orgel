import XCTest

@testable import Orgel

final class ReadOnlyObjectTests: XCTestCase {
    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
    }

    func testInit() throws {
        let model = TestUtils.makeModel0_0_1()
        let entity = try XCTUnwrap(model.entities[.objectA])

        let objectId = LoadingObjectId.stable(.init(1))
        let attributes: [Attribute.Name: SQLValue] = [
            .age: .integer(10), .name: .text("name_val"),
            .weight: .real(53.4),
            .init("hoge"): .text("moge"),
        ]

        let relations: [Relation.Name: [LoadingObjectId]] = [
            .children: [.stable(.init(12)), .stable(.init(34))]
        ]
        let data = LoadingObjectData(
            id: objectId,
            values: .init(
                pkId: 55, saveId: 555, action: .insert, attributes: attributes, relations: relations
            ))

        let object = ReadOnlyObject(entity: entity, data: data)

        XCTAssertEqual(object.loadedId.stable.rawValue, 1)
        XCTAssertEqual(object.action, .insert)
        XCTAssertEqual(object.saveId, 555)
        XCTAssertEqual(object.attributeValue(forName: .age), .integer(10))
        XCTAssertEqual(object.attributeValue(forName: .name), .text("name_val"))
        XCTAssertEqual(object.attributeValue(forName: .weight), .real(53.4))
        XCTAssertEqual(
            object.relationIds(forName: .children), [.stable(.init(12)), .stable(.init(34))])
    }

    @MainActor
    func testAction() throws {
        let model = TestUtils.makeModel0_0_1()
        let entity = try XCTUnwrap(model.entities[.objectA])
        let objectId = LoadingObjectId.stable(.init(1))

        XCTContext.runActivity(named: "nil") { _ in
            let object = ReadOnlyObject(
                entity: entity,
                data: .init(id: objectId, values: nil))

            XCTAssertNil(object.action)
        }

        XCTContext.runActivity(named: "insert") { _ in
            let object = ReadOnlyObject(
                entity: entity,
                data: .init(
                    id: objectId,
                    values: .init(
                        pkId: 77, saveId: 777, action: .insert, attributes: [:],
                        relations: [:])))

            XCTAssertEqual(object.action, .insert)
        }

        XCTContext.runActivity(named: "remove") { _ in
            let object = ReadOnlyObject(
                entity: entity,
                data: .init(
                    id: objectId,
                    values: .init(
                        pkId: 88, saveId: 888, action: .remove, attributes: [:],
                        relations: [:])))

            XCTAssertEqual(object.action, .remove)
        }

        XCTContext.runActivity(named: "update") { _ in
            let object = ReadOnlyObject(
                entity: entity,
                data: .init(
                    id: objectId,
                    values: .init(
                        pkId: 99, saveId: 999, action: .update, attributes: [:],
                        relations: [:])))

            XCTAssertEqual(object.action, .update)
        }
    }

    func testTyped() throws {
        let model = TestUtils.makeModel0_0_2()
        let entity = try XCTUnwrap(model.entities[.objectA])

        let objectId = LoadingObjectId.stable(.init(1))
        let attributes: [Attribute.Name: SQLValue] = [
            .pkId: .integer(22),
            .age: .integer(10), .name: .text("name_val"),
            .weight: .real(53.4),
            .tall: .real(174.2),
            .data: .blob(Data([0, 1])),
            .init("hoge"): .text("moge"),
            .saveId: .integer(100),
        ]

        let relations: [Relation.Name: [LoadingObjectId]] = [
            .children: [.stable(.init(12)), .stable(.init(34))],
            .friend: [.stable(.init(56))],
        ]
        let data = LoadingObjectData(
            id: objectId,
            values: .init(
                pkId: 44, saveId: 444, action: .insert, attributes: attributes,
                relations: relations))

        let object = ReadOnlyObject(entity: entity, data: data)

        let typedObject = try object.typed(ObjectA.self)

        XCTAssertEqual(typedObject.id.rawId, .stable(.init(1)))
        XCTAssertEqual(typedObject.attributes.age, 10)
        XCTAssertEqual(typedObject.attributes.name, "name_val")
        XCTAssertEqual(typedObject.attributes.weight, 53.4)
        XCTAssertEqual(typedObject.attributes.tall, 174.2)
        XCTAssertEqual(typedObject.attributes.data, Data([0, 1]))
    }
}
