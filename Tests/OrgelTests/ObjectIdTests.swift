import OrderedCollections
import XCTest

@testable import Orgel

final class ObjectIdTests: XCTestCase {
    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
    }

    func testStableId() {
        let objId = ObjectId.stable(.init(1))

        XCTAssertTrue(objId.isStable)
        XCTAssertFalse(objId.isTemporary)
        XCTAssertEqual(objId.stable?.rawValue, 1)
    }

    func testTemporaryId() {
        let objId = ObjectId.temporary(.init("2"))

        XCTAssertTrue(objId.isTemporary)
        XCTAssertFalse(objId.isStable)
        XCTAssertEqual(objId.temporary?.rawValue, "2")
    }

    func testStableIdByInit() {
        let objId = ObjectId(stable: .init(3), temporary: nil)

        XCTAssertTrue(objId.isStable)
        XCTAssertFalse(objId.isTemporary)
        XCTAssertEqual(objId.stable?.rawValue, 3)
    }

    func testBothIdByInit() {
        let objId = ObjectId(stable: .init(4), temporary: .init("5"))

        XCTAssertTrue(objId.isStable)
        XCTAssertFalse(objId.isTemporary)
        XCTAssertEqual(objId.stable?.rawValue, 4)
        XCTAssertEqual(objId.temporary?.rawValue, "5")
    }

    func testEquals() {
        let stableIdA1 = ObjectId.stable(.init(11))
        let stableIdA2 = ObjectId.stable(.init(11))
        let stableIdB = ObjectId.stable(.init(22))
        let temporaryIdA1 = ObjectId.temporary(.init("111"))
        let temporaryIdA2 = ObjectId.temporary(.init("111"))
        let temporaryIdB = ObjectId.temporary(.init("222"))
        let bothId = ObjectId.both(stable: .init(11), temporary: .init("111"))

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
        let stableId = ObjectId.stable(.init(1))
        let temporaryId = ObjectId.temporary(.init("1"))
        let bothId = ObjectId.both(stable: .init(2), temporary: .init("3"))

        XCTAssertTrue(stableId.isStable)
        XCTAssertFalse(temporaryId.isStable)
        XCTAssertTrue(bothId.isStable)
    }

    func testIsTemporary() {
        let stableId = ObjectId.stable(.init(1))
        let temporaryId = ObjectId.temporary(.init("1"))
        let bothId = ObjectId.both(stable: .init(2), temporary: .init("3"))

        XCTAssertFalse(stableId.isTemporary)
        XCTAssertTrue(temporaryId.isTemporary)
        XCTAssertFalse(bothId.isTemporary)
    }

    func testStableValue() {
        let stableId = ObjectId.stable(.init(1))
        let temporaryId = ObjectId.temporary(.init("1"))
        let bothId = ObjectId.both(stable: .init(2), temporary: .init("3"))

        XCTAssertEqual(stableId.stableValue, .integer(1))
        XCTAssertEqual(temporaryId.stableValue, .null)
        XCTAssertEqual(bothId.stableValue, .integer(2))
    }

    func testTemporaryValue() {
        let stableId = ObjectId.stable(.init(1))
        let temporaryId = ObjectId.temporary(.init("1"))
        let bothId = ObjectId.both(stable: .init(2), temporary: .init("3"))

        XCTAssertEqual(stableId.temporaryValue, .null)
        XCTAssertEqual(temporaryId.temporaryValue, .text("1"))
        XCTAssertEqual(bothId.temporaryValue, .text("3"))
    }

    func testLessThan() {
        XCTAssertTrue(ObjectId.stable(.init(1)) < ObjectId.stable(.init(2)))
        XCTAssertFalse(ObjectId.stable(.init(2)) < ObjectId.stable(.init(1)))
        XCTAssertTrue(ObjectId.temporary(.init("1")) < ObjectId.temporary(.init("2")))
        XCTAssertFalse(ObjectId.temporary(.init("2")) < ObjectId.temporary(.init("1")))
        XCTAssertTrue(
            ObjectId.both(stable: .init(1), temporary: .init("2"))
                < ObjectId.both(stable: .init(2), temporary: .init("1")))
        XCTAssertFalse(
            ObjectId.both(stable: .init(2), temporary: .init("1"))
                < ObjectId.both(stable: .init(1), temporary: .init("2")))
        XCTAssertTrue(ObjectId.stable(.init(2)) < ObjectId.temporary(.init("1")))
        XCTAssertFalse(ObjectId.temporary(.init("1")) < ObjectId.stable(.init(2)))
        XCTAssertTrue(
            ObjectId.stable(.init(2)) < ObjectId.both(stable: .init(3), temporary: .init("1")))
        XCTAssertFalse(
            ObjectId.both(stable: .init(3), temporary: .init("1")) < ObjectId.stable(.init(2)))
        XCTAssertTrue(
            ObjectId.both(stable: .init(2), temporary: .init("3")) < ObjectId.temporary(.init("1")))
        XCTAssertFalse(
            ObjectId.temporary(.init("1")) < ObjectId.both(stable: .init(2), temporary: .init("3")))
    }

    func testOrdering() {
        let stableId10 = ObjectId.stable(.init(10))
        let stableId20 = ObjectId.stable(.init(20))
        let stableId30 = ObjectId.stable(.init(30))
        let temporaryId5 = ObjectId.temporary(.init("05"))
        let temporaryId15 = ObjectId.temporary(.init("15"))
        let temporaryId25 = ObjectId.temporary(.init("25"))
        let bothId8 = ObjectId.both(stable: .init(8), temporary: .init("08"))
        let bothId18 = ObjectId.both(stable: .init(18), temporary: .init("18"))
        let bothId28 = ObjectId.both(stable: .init(28), temporary: .init("28"))

        var orderedSet = OrderedSet([
            bothId28, bothId18, bothId8, temporaryId25, temporaryId15, temporaryId5, stableId30,
            stableId20, stableId10,
        ])
        orderedSet.sort()

        XCTAssertEqual(orderedSet.count, 9)
        XCTAssertEqual(orderedSet[0], bothId8)
        XCTAssertEqual(orderedSet[1], stableId10)
        XCTAssertEqual(orderedSet[2], bothId18)
        XCTAssertEqual(orderedSet[3], stableId20)
        XCTAssertEqual(orderedSet[4], bothId28)
        XCTAssertEqual(orderedSet[5], stableId30)
        XCTAssertEqual(orderedSet[6], temporaryId5)
        XCTAssertEqual(orderedSet[7], temporaryId15)
        XCTAssertEqual(orderedSet[8], temporaryId25)
    }
}
