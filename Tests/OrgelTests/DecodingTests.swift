import XCTest

@testable import Orgel

final class DecodingTests: XCTestCase {
    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
    }

    func testDecode() throws {
        let model = TestUtils.makeModel0_0_2()
        let entity = try XCTUnwrap(model.entities[.objectA])
        let objectData = LoadingObjectData(
            id: .init(stable: .init(1), temporary: nil),
            values: .init(
                pkId: 505,
                saveId: 55,
                action: .insert,
                attributes: [
                    .age: .integer(111), .name: .text("test-name"), .weight: .real(2.0),
                    .tall: .null, .data: .blob(Data([0, 1])),
                ],
                relations: [
                    .children: [.stable(.init(10)), .stable(.init(11))],
                    .friend: [.stable(.init(20))],
                ]))

        let objectA = try ObjectDecoder().decode(ObjectA.self, from: objectData, entity: entity)

        XCTAssertEqual(objectA.id, .init(rawId: .stable(.init(1))))
        XCTAssertEqual(objectA.attributes.age, 111)
        XCTAssertEqual(objectA.attributes.name, "test-name")
        XCTAssertEqual(objectA.attributes.weight, 2.0)
        XCTAssertNil(objectA.attributes.tall)
        XCTAssertEqual(objectA.attributes.data, Data([0, 1]))
        XCTAssertEqual(
            objectA.relations.children,
            [.init(rawId: .stable(.init(10))), .init(rawId: .stable(.init(11)))])
        XCTAssertEqual(objectA.relations.friend, .init(rawId: .stable(.init(20))))
    }

    func testDecodeEmpty() throws {
        let model = TestUtils.makeModel0_0_2()
        let entity = try XCTUnwrap(model.entities[.objectA])
        let objectData = LoadingObjectData(
            id: .init(stable: .init(2), temporary: nil),
            values: .init(
                pkId: 505,
                saveId: 55,
                action: .insert,
                attributes: [.age: .integer(222)],
                relations: [:]))

        let objectA = try ObjectDecoder().decode(ObjectA.self, from: objectData, entity: entity)

        XCTAssertEqual(objectA.id, .init(rawId: .stable(.init(2))))
        XCTAssertEqual(objectA.attributes.age, 222)
        XCTAssertEqual(objectA.attributes.name, "default_value")
        XCTAssertEqual(objectA.attributes.weight, 65.4)
        XCTAssertEqual(objectA.attributes.tall, 172.4)
        XCTAssertNil(objectA.attributes.data)
        XCTAssertEqual(objectA.relations.children, [])
        XCTAssertNil(objectA.relations.friend)
    }
}
