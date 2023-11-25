import XCTest

@testable import Orgel

final class EncodingTests: XCTestCase {
    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
    }

    func testEncode() throws {
        let model = TestUtils.makeModel0_0_2()
        let entity = try XCTUnwrap(model.entities[.objectA])
        let id: ObjectA.Id = .init(rawId: .stable(.init(1)))
        let object = ObjectA(
            id: id,
            attributes: .init(
                age: 1, name: "test-name", weight: 2.0, tall: 4.0, data: Data([10, 11])),
            relations: .init(
                friend: .init(rawId: .stable(.init(10))),
                children: [.init(rawId: .stable(.init(11))), .init(rawId: .stable(.init(12)))]))

        let objectData = try ObjectEncoder().encode(object, entity: entity)

        XCTAssertEqual(objectData.id, id.rawId)
        XCTAssertEqual(objectData.attributes.count, 5)
        XCTAssertEqual(objectData.attributes[.age]?.integerValue, 1)
        XCTAssertEqual(objectData.attributes[.name]?.textValue, "test-name")
        XCTAssertEqual(objectData.attributes[.weight]?.realValue, 2.0)
        XCTAssertEqual(objectData.attributes[.tall]?.realValue, 4.0)
        XCTAssertEqual(objectData.attributes[.data]?.blobValue, Data([10, 11]))
        XCTAssertEqual(objectData.relations.count, 2)
        XCTAssertEqual(objectData.relations[.friend], [.stable(.init(10))])
        XCTAssertEqual(objectData.relations[.children], [.stable(.init(11)), .stable(.init(12))])
    }
}
