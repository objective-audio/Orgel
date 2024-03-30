import XCTest

@testable import Orgel

final class SyncedObjectIdTests: XCTestCase {
    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
    }

    func testStableId() {
        let objId = SyncedObjectId(stable: .init(1))

        XCTAssertTrue(objId.objectId.isStable)
        XCTAssertFalse(objId.objectId.isTemporary)
        XCTAssertEqual(objId.stable?.rawValue, 1)
    }

    func testTemporaryId() {
        let objId = SyncedObjectId(temporary: "2")

        XCTAssertTrue(objId.objectId.isTemporary)
        XCTAssertFalse(objId.objectId.isStable)
        XCTAssertEqual(objId.temporary?.rawValue, "2")
    }

    func testReplaceBothIdWithSameTemporaryRawValue() {
        var objectId = SyncedObjectId(temporary: "10")

        XCTAssertTrue(objectId.hasValue)
        XCTAssertEqual(objectId.objectId, .temporary(.init("10")))

        // temporaryが同じでないと更新できない

        objectId.replaceId(
            .both(stable: .init(20), temporary: .init("10")))

        XCTAssertEqual(objectId.objectId, .both(stable: .init(20), temporary: .init("10")))
    }

    func testReplaceStableIdWithTemporaryRawValue() {
        var objectId = SyncedObjectId(temporary: "10")

        XCTAssertTrue(objectId.hasValue)
        XCTAssertEqual(objectId.objectId, .temporary(.init("10")))

        // stableのみで更新できる

        objectId.replaceId(.stable(.init(21)))

        XCTAssertEqual(objectId.objectId, .stable(.init(21)))
    }

    func testReplaceBothIdWithoutRawValue() {
        // SyncedObjectId生成直後で内部的な値がない場合にbothIdで更新できる

        var objectId = SyncedObjectId()

        XCTAssertFalse(objectId.hasValue)

        objectId.replaceId(
            .both(stable: .init(20), temporary: .init("11")))

        XCTAssertEqual(objectId.objectId, .both(stable: .init(20), temporary: .init("11")))
    }

    func testReplaceStableIdWithoutRawValue() {
        // SyncedObjectId生成直後で内部的な値がない場合にstableIdで更新できる

        var objectId = SyncedObjectId()

        XCTAssertFalse(objectId.hasValue)

        objectId.replaceId(.stable(.init(30)))

        XCTAssertEqual(objectId.objectId, .stable(.init(30)))
    }

    func testEquals() {
        let stableIdA1 = SyncedObjectId(stable: .init(11))
        let stableIdA2 = SyncedObjectId(stable: .init(11))
        let stableIdB = SyncedObjectId(stable: .init(22))
        let temporaryIdA1 = SyncedObjectId(temporary: "111")
        let temporaryIdA2 = SyncedObjectId(temporary: "111")
        let temporaryIdB = SyncedObjectId(temporary: "222")
        let bothId = SyncedObjectId(stable: .init(11), temporary: "111")

        XCTAssertEqual(stableIdA1, stableIdA1)
        XCTAssertEqual(stableIdA1, stableIdA2)
        XCTAssertNotEqual(stableIdA1, stableIdB)

        XCTAssertEqual(temporaryIdA1, temporaryIdA1)
        XCTAssertEqual(temporaryIdA1, temporaryIdA2)
        XCTAssertNotEqual(temporaryIdA1, temporaryIdB)

        XCTAssertEqual(bothId, temporaryIdA1)
        XCTAssertEqual(bothId, stableIdA1)
        XCTAssertNotEqual(bothId, temporaryIdB)
        XCTAssertNotEqual(bothId, stableIdB)
    }

    func testIsStable() {
        let stableId = SyncedObjectId(stable: .init(1))
        var temporaryId = SyncedObjectId()
        temporaryId.setNewTemporary()
        let bothId = SyncedObjectId(stable: .init(2), temporary: "3")

        XCTAssertTrue(stableId.objectId.isStable)
        XCTAssertFalse(temporaryId.objectId.isStable)
        XCTAssertTrue(bothId.objectId.isStable)
    }

    func testIsTemporary() {
        let stableId = SyncedObjectId(stable: .init(1))
        var temporaryId = SyncedObjectId()
        temporaryId.setNewTemporary()
        let bothId = SyncedObjectId(stable: .init(2), temporary: "3")

        XCTAssertFalse(stableId.objectId.isTemporary)
        XCTAssertTrue(temporaryId.objectId.isTemporary)
        XCTAssertFalse(bothId.objectId.isTemporary)
    }
}
