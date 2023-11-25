import Orgel
import XCTest

final class EntityTests: XCTestCase {
    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
    }

    func testInit() throws {
        let attr = Entity.AttributeArgs(name: .init("attr_name"), value: .integer(.allowNull(1)))
        let rel = Entity.RelationArgs(name: .init("rel_name"), target: .init("test_target"))
        let invRels: [Entity.Name: Set<Relation.Name>] = [
            .init("inv_entity_name"): [.init("inv_rel_name_1"), .init("inv_rel_name_2")]
        ]

        let entity = try Entity(
            name: .init("entity_name"), attributes: [attr], relations: [rel],
            inverseRelationNames: invRels
        )

        XCTAssertEqual(entity.name, .init("entity_name"))
        XCTAssertEqual(entity.allAttributes.count, 5)
        XCTAssertEqual(entity.customAttributes.count, 1)
        XCTAssertEqual(entity.relations.count, 1)
    }
}
