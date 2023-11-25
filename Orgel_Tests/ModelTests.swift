import XCTest

final class ModelTests: XCTestCase {
    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
    }

    func testLoadModel() throws {
        let model = TestUtils.makeModel0_0_1()

        XCTAssertEqual(model.version.stringValue, "0.0.1")

        let entities = model.entities
        XCTAssertEqual(entities.count, 2)

        let entityA = try XCTUnwrap(entities[.objectA])
        let attributesA = entityA.allAttributes
        XCTAssertEqual(attributesA.count, 8)

        let pkIdAttributeA = try XCTUnwrap(attributesA[.init("pk_id")])
        XCTAssertEqual(pkIdAttributeA.name, .init("pk_id"))
        XCTAssertEqual(pkIdAttributeA.value, .integer(.allowNull(nil)))
        XCTAssertEqual(pkIdAttributeA.defaultValue, .null)
        XCTAssertFalse(pkIdAttributeA.notNull)
        XCTAssertTrue(pkIdAttributeA.primary)
        XCTAssertFalse(pkIdAttributeA.unique)

        let objectIdAttributeA = try XCTUnwrap(attributesA[.init("obj_id")])
        XCTAssertEqual(objectIdAttributeA.name, .init("obj_id"))
        XCTAssertEqual(objectIdAttributeA.value, .integer(.notNull(0)))
        XCTAssertEqual(objectIdAttributeA.defaultValue, .integer(0))
        XCTAssertTrue(objectIdAttributeA.notNull)
        XCTAssertFalse(objectIdAttributeA.primary)
        XCTAssertFalse(objectIdAttributeA.unique)

        let saveIdAttributeA = try XCTUnwrap(attributesA[.init("save_id")])
        XCTAssertEqual(saveIdAttributeA.name, .init("save_id"))
        XCTAssertEqual(saveIdAttributeA.value, .integer(.notNull(0)))
        XCTAssertEqual(saveIdAttributeA.defaultValue, .integer(0))
        XCTAssertTrue(saveIdAttributeA.notNull)
        XCTAssertFalse(saveIdAttributeA.primary)
        XCTAssertFalse(saveIdAttributeA.unique)

        let actionAttributeA = try XCTUnwrap(attributesA[.init("action")])
        XCTAssertEqual(actionAttributeA.name, .init("action"))
        XCTAssertEqual(actionAttributeA.value, .text(.notNull("insert")))
        XCTAssertEqual(actionAttributeA.defaultValue, .text("insert"))
        XCTAssertTrue(actionAttributeA.notNull)
        XCTAssertFalse(actionAttributeA.primary)
        XCTAssertFalse(actionAttributeA.unique)

        let ageAttributeA = try XCTUnwrap(attributesA[.age])
        XCTAssertEqual(ageAttributeA.name, .age)
        XCTAssertEqual(ageAttributeA.value, .integer(.notNull(10)))
        XCTAssertEqual(ageAttributeA.defaultValue, .integer(10))
        XCTAssertTrue(ageAttributeA.notNull)
        XCTAssertFalse(ageAttributeA.primary)
        XCTAssertFalse(ageAttributeA.unique)

        let nameAttributeA = try XCTUnwrap(attributesA[.name])
        XCTAssertEqual(nameAttributeA.name, .name)
        XCTAssertEqual(nameAttributeA.value, .text(.allowNull("default_value")))
        XCTAssertEqual(nameAttributeA.defaultValue, .text("default_value"))
        XCTAssertFalse(nameAttributeA.notNull)
        XCTAssertFalse(nameAttributeA.primary)
        XCTAssertFalse(nameAttributeA.unique)

        let weightAttributeA = try XCTUnwrap(attributesA[.weight])
        XCTAssertEqual(weightAttributeA.name, .weight)
        XCTAssertEqual(weightAttributeA.value, .real(.allowNull(65.4)))
        XCTAssertEqual(weightAttributeA.defaultValue, .real(65.4))
        XCTAssertFalse(weightAttributeA.notNull)
        XCTAssertFalse(weightAttributeA.primary)
        XCTAssertFalse(weightAttributeA.unique)

        let dataAttributeA = try XCTUnwrap(attributesA[.data])
        XCTAssertEqual(dataAttributeA.name, .data)
        XCTAssertEqual(dataAttributeA.value, .blob(.allowNull(nil)))
        XCTAssertEqual(dataAttributeA.defaultValue, .null)
        XCTAssertEqual(dataAttributeA.notNull, false)
        XCTAssertEqual(dataAttributeA.primary, false)
        XCTAssertEqual(dataAttributeA.unique, false)

        let customAttributesA = entityA.customAttributes
        XCTAssertEqual(customAttributesA.count, 4)
        XCTAssertNil(customAttributesA[.init("pk_id")])
        XCTAssertNil(customAttributesA[.init("obj_id")])
        XCTAssertNil(customAttributesA[.init("save_id")])
        XCTAssertNil(customAttributesA[.init("action")])
        XCTAssertNotNil(customAttributesA[.age])
        XCTAssertNotNil(customAttributesA[.name])
        XCTAssertNotNil(customAttributesA[.weight])
        XCTAssertNotNil(customAttributesA[.data])

        let entityB = try XCTUnwrap(entities[.objectB])
        let attributesB = entityB.allAttributes
        XCTAssertEqual(attributesB.count, 5)

        let idAttributeB = try XCTUnwrap(attributesB[.init("pk_id")])
        XCTAssertEqual(idAttributeB.name, .init("pk_id"))
        XCTAssertEqual(idAttributeB.value, .integer(.allowNull(nil)))
        XCTAssertEqual(idAttributeB.defaultValue, .null)
        XCTAssertFalse(idAttributeB.notNull)
        XCTAssertTrue(idAttributeB.primary)
        XCTAssertFalse(idAttributeB.unique)

        let saveIdAttributeB = try XCTUnwrap(attributesB[.init("save_id")])
        XCTAssertEqual(saveIdAttributeB.name, .init("save_id"))
        XCTAssertEqual(saveIdAttributeB.value, .integer(.notNull(0)))
        XCTAssertEqual(saveIdAttributeB.defaultValue, .integer(0))
        XCTAssertTrue(saveIdAttributeB.notNull)
        XCTAssertFalse(saveIdAttributeB.primary)
        XCTAssertFalse(saveIdAttributeB.unique)

        let actionAttributeB = try XCTUnwrap(attributesB[.init("action")])
        XCTAssertEqual(actionAttributeB.name, .init("action"))
        XCTAssertEqual(actionAttributeB.value, .text(.notNull("insert")))
        XCTAssertEqual(actionAttributeB.defaultValue, .text("insert"))
        XCTAssertTrue(actionAttributeB.notNull)
        XCTAssertFalse(actionAttributeB.primary)
        XCTAssertFalse(actionAttributeB.unique)

        let nameAttributeB = try XCTUnwrap(attributesB[.fullname])
        XCTAssertEqual(nameAttributeB.name, .fullname)
        XCTAssertEqual(nameAttributeB.value, .text(.allowNull(nil)))
        XCTAssertEqual(nameAttributeB.defaultValue, .null)
        XCTAssertFalse(nameAttributeB.notNull)
        XCTAssertFalse(nameAttributeB.primary)
        XCTAssertFalse(nameAttributeB.unique)

        let customAttributesB = entityB.customAttributes
        XCTAssertEqual(customAttributesB.count, 1)
        XCTAssertNil(customAttributesB[.init("pk_id")])
        XCTAssertNil(customAttributesB[.init("obj_id")])
        XCTAssertNil(customAttributesB[.init("save_id")])
        XCTAssertNil(customAttributesB[.init("action")])
        XCTAssertNotNil(customAttributesB[.fullname])

        let relations = entityA.relations
        XCTAssertEqual(relations.count, 1)

        let child = try XCTUnwrap(relations[.children])
        XCTAssertEqual(child.source, .objectA)
        XCTAssertEqual(child.name, .children)
        XCTAssertEqual(child.target, .objectB)

        let invRelNamesA = entityA.inverseRelationNames
        XCTAssertEqual(invRelNamesA.count, 0)

        let invRelNamesB = entityB.inverseRelationNames
        XCTAssertEqual(invRelNamesB.count, 1)
        let objectAInvRelNames = try XCTUnwrap(invRelNamesB[.objectA])
        XCTAssertEqual(objectAInvRelNames.count, 1)
        XCTAssertNotNil(objectAInvRelNames.contains(.children))
    }
}
