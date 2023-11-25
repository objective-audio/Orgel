import XCTest

@testable import Orgel

final class ObjectEventTests: XCTestCase {
    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
    }

    @MainActor
    func testIsChanged() throws {
        let model = TestUtils.makeModel0_0_1()
        let entity = try XCTUnwrap(model.entities[.objectA])
        let object = SyncedObject(entity: entity)

        XCTAssertTrue(
            ObjectEvent.attributeUpdated(object: object, name: .name, value: .null).isChanged)
        XCTAssertTrue(
            ObjectEvent.relationInserted(object: object, name: .children, indices: []).isChanged)
        XCTAssertTrue(ObjectEvent.relationReplaced(object: object, name: .children).isChanged)
        XCTAssertTrue(
            ObjectEvent.relationRemoved(object: object, name: .children, indices: []).isChanged)

        XCTAssertFalse(ObjectEvent.fetched(object: object).isChanged)
        XCTAssertFalse(ObjectEvent.loaded(object: object).isChanged)
        XCTAssertFalse(ObjectEvent.cleared(object: object).isChanged)
    }

    @MainActor
    func testChangedObject() throws {
        let model = TestUtils.makeModel0_0_1()
        let entity = try XCTUnwrap(model.entities[.objectA])
        let object = SyncedObject(entity: entity)
        object.loadInsertionData()

        XCTAssertEqual(
            ObjectEvent.attributeUpdated(object: object, name: .name, value: .null).changedObject?
                .id, object.id)
        XCTAssertEqual(
            ObjectEvent.relationInserted(object: object, name: .children, indices: [])
                .changedObject?.id, object.id)
        XCTAssertEqual(
            ObjectEvent.relationReplaced(object: object, name: .children).changedObject?.id,
            object.id)
        XCTAssertEqual(
            ObjectEvent.relationRemoved(object: object, name: .children, indices: []).changedObject?
                .id, object.id)

        XCTAssertNil(ObjectEvent.fetched(object: object).changedObject)
        XCTAssertNil(ObjectEvent.loaded(object: object).changedObject)
        XCTAssertNil(ObjectEvent.cleared(object: object).changedObject)
    }
}
