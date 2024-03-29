import XCTest

@testable import Orgel

final class SyncedObjectTests: XCTestCase {
    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
    }

    @MainActor
    func testInitMutable() throws {
        let model = TestUtils.makeModel0_0_1()
        let entity = try XCTUnwrap(model.entities[.objectA])
        let object = SyncedObject(entity: entity)

        XCTAssertEqual(object.entity.name, .objectA)
        XCTAssertEqual(object.attributeValue(forName: .age), .null)
        XCTAssertEqual(object.attributeValue(forName: .name), .null)
        XCTAssertEqual(object.attributeValue(forName: .weight), .null)
        // idはLoadしないで呼び出すとクラッシュする
        // XCTAssertTrue(object.id.isTemporary)
        XCTAssertEqual(object.relationIds(forName: .children).count, 0)
        XCTAssertEqual(object.action, nil)
    }

    @MainActor
    func testLoadValues() throws {
        let model = TestUtils.makeModel0_0_1()
        let entity = try XCTUnwrap(model.entities[.objectA])
        let object = SyncedObject(entity: entity)

        let objectId = LoadingObjectId.stable(.init(1))
        let attributes: [Attribute.Name: SQLValue] = [
            .age: .integer(10), .name: .text("name_val"),
            .weight: .real(53.4),
            .init("hoge"): .text("hoge_value"),
        ]
        let relations: [Relation.Name: [LoadingObjectId]] = [
            .children: [.stable(.init(12)), .stable(.init(34))]
        ]
        let data = LoadingObjectData(
            id: objectId,
            values: .init(
                pkId: 55, saveId: 555, action: .insert, attributes: attributes,
                relations: relations))

        object.loadData(data, force: false)

        XCTAssertEqual(object.id.stable?.rawValue, 1)
        XCTAssertEqual(object.action, .insert)
        XCTAssertEqual(object.saveId, 555)
        XCTAssertEqual(object.attributeValue(forName: .age), .integer(10))
        XCTAssertEqual(object.attributeValue(forName: .name), .text("name_val"))
        XCTAssertEqual(object.attributeValue(forName: .weight), .real(53.4))

        XCTAssertEqual(
            object.relationIds(forName: .children), [.stable(.init(12)), .stable(.init(34))])
    }

    @MainActor
    func testReloadValues() throws {
        let model = TestUtils.makeModel0_0_1()
        let entity = try XCTUnwrap(model.entities[.objectA])
        let object = SyncedObject(entity: entity)

        let objectId = LoadingObjectId.stable(.init(1))
        let prevAttributes: [Attribute.Name: SQLValue] = [
            .age: .integer(10), .name: .text("name_val"),
            .weight: .real(53.4),
            .init("hoge"): .text("moge"),
        ]
        let prevRelations: [Relation.Name: [LoadingObjectId]] = [
            .children: [.stable(.init(12)), .stable(.init(34))]
        ]
        let prevData = LoadingObjectData(
            id: objectId,
            values: .init(
                pkId: 66, saveId: 666, action: .insert, attributes: prevAttributes,
                relations: prevRelations))

        object.loadData(prevData, force: false)

        let postObjectId = LoadingObjectId.stable(.init(1))
        let postAttributes: [Attribute.Name: SQLValue] = [
            .age: .integer(543), .init("hoge"): .text("poke"),
        ]
        let postRelations: [Relation.Name: [LoadingObjectId]] = [
            .children: [.stable(.init(234)), .stable(.init(567)), .stable(.init(890))]
        ]
        let postData = LoadingObjectData(
            id: postObjectId,
            values: .init(
                pkId: 77, saveId: 777, action: .insert, attributes: postAttributes,
                relations: postRelations))

        object.loadData(postData, force: false)

        XCTAssertEqual(object.id.stable?.rawValue, 1)

        XCTAssertEqual(object.attributeValue(forName: .age), .integer(543))
        XCTAssertEqual(object.attributeValue(forName: .name), .null)
        XCTAssertEqual(object.attributeValue(forName: .weight), .null)

        XCTAssertEqual(
            object.relationIds(forName: .children),
            [.stable(.init(234)), .stable(.init(567)), .stable(.init(890))])
    }

    @MainActor
    func testLoadAfterCreatedObjectChanged() throws {
        // 未保存のオブジェクトの保存を開始して、ロードされる前に値を変更した場合

        let model = TestUtils.makeModel0_0_1()
        let entity = try XCTUnwrap(model.entities[.objectA])
        let object = SyncedObject(entity: entity)
        object.loadInsertionData()

        XCTAssertEqual(object.attributeValue(forName: .age), .integer(10))
        XCTAssertEqual(object.status, .created)

        // 保存開始する

        let savingData = try object.objectDataForSave()

        object.setStatusToSaving()

        XCTAssertEqual(object.status, .saving)

        // ロードされる前に値を変更する

        object.setAttributeValue(.integer(11), forName: .age)

        XCTAssertEqual(object.action, .insert)
        XCTAssertEqual(object.status, .changed)

        // ロードする

        var loadingAttributes = savingData.attributes
        loadingAttributes[.age] = .integer(20)
        let loadingData = LoadingObjectData(
            id: .init(stable: .init(1), temporary: savingData.id.temporary!),
            values: .init(
                pkId: 1, saveId: 1, action: .insert, attributes: loadingAttributes, relations: [:]))

        object.loadData(loadingData, force: false)

        XCTAssertEqual(object.action, .insert)
        XCTAssertEqual(object.status, .changed)
        XCTAssertEqual(object.attributeValue(forName: .age), .integer(11))

        // ロード後に保存する

        object.setStatusToSaving()

        XCTAssertEqual(object.status, .saving)

        object.loadData(loadingData, force: false)

        XCTAssertEqual(object.action, .insert)
        XCTAssertEqual(object.status, .saved)
        XCTAssertEqual(object.attributeValue(forName: .age), .integer(20))
    }

    @MainActor
    func testLoadAfterCreatedObjectAborted() throws {
        // 未保存のオブジェクトの保存を開始して、ロードされる前に削除した場合

        let model = TestUtils.makeModel0_0_1()
        let entity = try XCTUnwrap(model.entities[.objectA])
        let object = SyncedObject(entity: entity)
        object.loadInsertionData()

        XCTAssertEqual(object.status, .created)

        // 保存を開始する

        let savingData = try object.objectDataForSave()
        let stableId = LoadingObjectId(stable: .init(1), temporary: savingData.id.temporary!)

        object.setStatusToSaving()

        XCTAssertEqual(object.status, .saving)
        XCTAssertEqual(object.action, .insert)

        // ロード前に削除する

        object.remove()

        XCTAssertEqual(object.status, .changed)
        XCTAssertEqual(object.action, .remove)

        // ロードする

        var loadingAttributes = savingData.attributes
        loadingAttributes[.age] = .integer(20)
        let loadingData = LoadingObjectData(
            id: stableId,
            values: .init(
                pkId: 1, saveId: 1, action: .insert, attributes: loadingAttributes, relations: [:]))

        object.loadData(loadingData, force: false)

        XCTAssertEqual(object.status, .changed)
        XCTAssertEqual(object.action, .remove)

        // ロード後に保存する

        object.setStatusToSaving()

        XCTAssertEqual(object.status, .saving)

        let loadingRemovedData = LoadingObjectData(
            id: stableId,
            values: .init(pkId: 2, saveId: 2, action: .remove, attributes: [:], relations: [:]))

        object.loadData(loadingRemovedData, force: false)

        XCTAssertEqual(object.status, .saved)
        XCTAssertEqual(object.action, .remove)
    }

    @MainActor
    func testSetAndGetValue() throws {
        let model = TestUtils.makeModel0_0_1()
        let entity = try XCTUnwrap(model.entities[.objectA])
        let object = SyncedObject(entity: entity)
        object.loadInsertionData()

        object.setAttributeValue(.integer(24), forName: .age)
        object.setAttributeValue(.text("nabe"), forName: .name)
        object.setAttributeValue(.real(5783.23), forName: .weight)

        XCTAssertEqual(object.attributeValue(forName: .age), .integer(24))
        XCTAssertEqual(object.attributeValue(forName: .name), .text("nabe"))
        XCTAssertEqual(object.attributeValue(forName: .weight), .real(5783.23))
    }

    @MainActor
    func testAddAndRemoveRelationId() throws {
        let model = TestUtils.makeModel0_0_1()
        let entity = try XCTUnwrap(model.entities[.objectA])
        let object = SyncedObject(entity: entity)
        object.loadInsertionData()

        object.addRelationId(.stable(.init(321)), forName: .children)

        XCTAssertEqual(object.relationIds(forName: .children).count, 1)

        object.addRelationId(.stable(.init(654)), forName: .children)

        XCTAssertEqual(object.relationIds(forName: .children).count, 2)

        object.addRelationId(.stable(.init(987)), forName: .children)

        XCTAssertEqual(object.relationIds(forName: .children).count, 3)
        XCTAssertEqual(object.relationIds(forName: .children)[0].stable?.rawValue, 321)
        XCTAssertEqual(object.relationIds(forName: .children)[1].stable?.rawValue, 654)
        XCTAssertEqual(object.relationIds(forName: .children)[2].stable?.rawValue, 987)

        object.removeRelationId(.stable(.init(654)), forName: .children)

        XCTAssertEqual(object.relationIds(forName: .children).count, 2)
        XCTAssertEqual(object.relationIds(forName: .children)[0].stable?.rawValue, 321)
        XCTAssertEqual(object.relationIds(forName: .children)[1].stable?.rawValue, 987)

        object.removeRelation(forName: .children, at: 0)

        XCTAssertEqual(object.relationIds(forName: .children).count, 1)
        XCTAssertEqual(object.relationIds(forName: .children)[0].stable?.rawValue, 987)

        object.removeAllRelations(forName: .children)

        XCTAssertEqual(object.relationIds(forName: .children).count, 0)
    }

    @MainActor
    func testAddAndRemoveRelationObject() throws {
        let model = TestUtils.makeModel0_0_1()
        let entityA = try XCTUnwrap(model.entities[.objectA])
        let entityB = try XCTUnwrap(model.entities[.objectB])

        let object = SyncedObject(entity: entityA)
        object.loadInsertionData()

        let objectB1 = SyncedObject(entity: entityB)
        let objectB2 = SyncedObject(entity: entityB)
        let objectB3 = SyncedObject(entity: entityB)

        objectB1.loadData(
            .init(
                id: .stable(.init(5)),
                values: .init(
                    pkId: 55, saveId: 555, action: .insert, attributes: [:],
                    relations: [:])),
            force: false
        )
        objectB2.loadData(
            .init(
                id: .stable(.init(6)),
                values: .init(
                    pkId: 66, saveId: 666, action: .insert, attributes: [:],
                    relations: [:])),
            force: false
        )
        objectB3.loadData(
            .init(
                id: .stable(.init(7)),
                values: .init(
                    pkId: 77, saveId: 777, action: .insert, attributes: [:],
                    relations: [:])),
            force: false
        )

        object.addRelationObject(objectB1, forName: .children)

        XCTAssertEqual(object.relationIds(forName: .children).count, 1)

        object.addRelationObject(objectB2, forName: .children)

        XCTAssertEqual(object.relationIds(forName: .children).count, 2)

        object.addRelationObject(objectB3, forName: .children)

        XCTAssertEqual(object.relationIds(forName: .children).count, 3)
        XCTAssertEqual(object.relationIds(forName: .children)[0].stable?.rawValue, 5)
        XCTAssertEqual(object.relationIds(forName: .children)[1].stable?.rawValue, 6)
        XCTAssertEqual(object.relationIds(forName: .children)[2].stable?.rawValue, 7)

        object.removeRelationObject(objectB2, forName: .children)

        XCTAssertEqual(object.relationIds(forName: .children).count, 2)
        XCTAssertEqual(object.relationIds(forName: .children)[0].stable?.rawValue, 5)
        XCTAssertEqual(object.relationIds(forName: .children)[1].stable?.rawValue, 7)

        object.removeRelation(forName: .children, at: 0)

        XCTAssertEqual(object.relationIds(forName: .children).count, 1)
        XCTAssertEqual(object.relationIds(forName: .children)[0].stable?.rawValue, 7)

        object.removeAllRelations(forName: .children)

        XCTAssertEqual(object.relationIds(forName: .children).count, 0)
    }

    @MainActor
    func testInsertRelationId() throws {
        let model = TestUtils.makeModel0_0_1()
        let entityA = try XCTUnwrap(model.entities[.objectA])

        let object = SyncedObject(entity: entityA)
        object.loadInsertionData()

        object.insertRelationId(.stable(.init(5)), forName: .children, at: 0)

        XCTAssertEqual(object.relationIds(forName: .children).count, 1)

        object.insertRelationId(.stable(.init(6)), forName: .children, at: 1)

        XCTAssertEqual(object.relationIds(forName: .children).count, 2)

        object.insertRelationId(.stable(.init(7)), forName: .children, at: 0)

        XCTAssertEqual(object.relationIds(forName: .children).count, 3)

        XCTAssertEqual(object.relationIds(forName: .children)[0].stable?.rawValue, 7)
        XCTAssertEqual(object.relationIds(forName: .children)[1].stable?.rawValue, 5)
        XCTAssertEqual(object.relationIds(forName: .children)[2].stable?.rawValue, 6)
    }

    @MainActor
    func testInsertRelationObject() throws {
        let model = TestUtils.makeModel0_0_1()
        let entityA = try XCTUnwrap(model.entities[.objectA])
        let entityB = try XCTUnwrap(model.entities[.objectB])

        let object = SyncedObject(entity: entityA)
        object.loadInsertionData()

        let objectB1 = SyncedObject(entity: entityB)
        let objectB2 = SyncedObject(entity: entityB)
        let objectB3 = SyncedObject(entity: entityB)

        objectB1.loadData(
            .init(
                id: .stable(.init(5)),
                values: .init(
                    pkId: 55, saveId: 555, action: .insert, attributes: [:],
                    relations: [:])),
            force: false
        )
        objectB2.loadData(
            .init(
                id: .stable(.init(6)),
                values: .init(
                    pkId: 66, saveId: 666, action: .insert, attributes: [:],
                    relations: [:])),
            force: false
        )
        objectB3.loadData(
            .init(
                id: .stable(.init(7)),
                values: .init(
                    pkId: 77, saveId: 777, action: .insert, attributes: [:],
                    relations: [:])),
            force: false
        )

        object.insertRelationObject(objectB1, forName: .children, at: 0)

        XCTAssertEqual(object.relationIds(forName: .children).count, 1)

        object.insertRelationObject(objectB2, forName: .children, at: 1)

        XCTAssertEqual(object.relationIds(forName: .children).count, 2)

        object.insertRelationObject(objectB3, forName: .children, at: 0)

        XCTAssertEqual(object.relationIds(forName: .children).count, 3)

        XCTAssertEqual(object.relationIds(forName: .children)[0].stable?.rawValue, 7)
        XCTAssertEqual(object.relationIds(forName: .children)[1].stable?.rawValue, 5)
        XCTAssertEqual(object.relationIds(forName: .children)[2].stable?.rawValue, 6)
    }

    @MainActor
    func testReplaceValue() throws {
        let model = TestUtils.makeModel0_0_1()
        let entity = try XCTUnwrap(model.entities[.objectA])
        let object = SyncedObject(entity: entity)
        object.loadInsertionData()

        object.setAttributeValue(.integer(1), forName: .age)

        XCTAssertEqual(object.attributeValue(forName: .age), .integer(1))

        object.setAttributeValue(.integer(5), forName: .age)

        XCTAssertEqual(object.attributeValue(forName: .age), .integer(5))
    }

    @MainActor
    func testRemove() throws {
        let model = TestUtils.makeModel0_0_1()
        let entity = try XCTUnwrap(model.entities[.objectA])
        let object = SyncedObject(entity: entity)

        XCTAssertNotEqual(object.action, .remove)

        object.loadData(
            .init(
                id: .stable(.init(45)),
                values: .init(
                    pkId: 55, saveId: 555, action: .insert, attributes: [:],
                    relations: [:])),
            force: false)
        object.setAttributeValue(.text("tanaka"), forName: .name)
        object.setRelationIds([.stable(.init(111))], forName: .children)

        XCTAssertEqual(object.id.stable?.rawValue, 45)
        XCTAssertEqual(object.attributeValue(forName: .name), .text("tanaka"))
        XCTAssertEqual(object.relationIds(forName: .children)[0].stable?.rawValue, 111)

        object.remove()

        XCTAssertEqual(object.action, .remove)
        XCTAssertEqual(object.attributeValue(forName: .name), .null)
        XCTAssertEqual(object.id.stable?.rawValue, 45)
        XCTAssertEqual(object.relationIds(forName: .children).count, 0)

        // removeした後はattributeやrelationを更新できない

        object.setAttributeValue(.text("name-after-removed"), forName: .name)
        object.setRelationIds([.stable(.init(112))], forName: .children)
        object.addRelationId(.stable(.init(113)), forName: .children)
        object.insertRelationId(.stable(.init(114)), forName: .children, at: 0)

        XCTAssertEqual(object.attributeValue(forName: .name), .null)
        XCTAssertEqual(object.relationIds(forName: .children).count, 0)

        // removeした後にrelationをremoveしようとしても何も起きない
        object.removeRelationId(.stable(.init(115)), forName: .children)

        // loadしたらattributeやrelationを更新できる
        object.clearData()
        object.loadData(
            .init(
                id: .stable(.init(45)),
                values: .init(
                    pkId: 55, saveId: 555, action: .insert,
                    attributes: [.saveId: .integer(1)],
                    relations: [:])),
            force: false)

        object.setAttributeValue(.text("name-after-loaded"), forName: .name)
        object.setRelationIds([.stable(.init(116))], forName: .children)

        XCTAssertEqual(object.attributeValue(forName: .name), .text("name-after-loaded"))
        XCTAssertEqual(object.relationIds(forName: .children), [.stable(.init(116))])
    }

    @MainActor
    func testAction() throws {
        let model = TestUtils.makeModel0_0_1()
        let entity = try XCTUnwrap(model.entities[.objectA])
        let object = SyncedObject(entity: entity)

        XCTAssertNil(object.action)

        let data = LoadingObjectData(
            id: .stable(.init(0)),
            values: .init(
                pkId: 55,
                saveId: 555,
                action: .insert,
                attributes: [.action: .insertAction],
                relations: [.children: [.stable(.init(12)), .stable(.init(34))]]))

        let reload = {
            object.loadData(data, force: true)
            XCTAssertEqual(object.action, .insert)
        }

        reload()

        XCTAssertEqual(object.action, .insert)

        object.setAttributeValue(.text("test_name"), forName: .name)
        XCTAssertEqual(object.action, .update)

        reload()

        object.addRelationId(.stable(.init(2)), forName: .children)
        XCTAssertEqual(object.action, .update)

        reload()

        object.setRelationIds([.stable(.init(1))], forName: .children)
        XCTAssertEqual(object.action, .update)

        reload()

        object.removeRelation(forName: .children, at: 0)
        XCTAssertEqual(object.action, .update)

        reload()

        object.removeAllRelations(forName: .children)
        XCTAssertEqual(object.action, .update)

        reload()

        object.remove()
        XCTAssertEqual(object.action, .remove)
    }

    @MainActor
    func testObjectDataForSave() throws {
        let model = TestUtils.makeModel0_0_1()
        let entity = try XCTUnwrap(model.entities[.objectA])
        let object = SyncedObject(entity: entity)

        object.loadData(
            .init(
                id: .stable(.init(55)),
                values: .init(
                    pkId: 505, saveId: 555, action: .insert, attributes: [:],
                    relations: [:])),
            force: false)

        object.setAttributeValue(.text("suzuki"), forName: .name)
        object.setAttributeValue(.integer(32), forName: .age)
        object.setAttributeValue(.real(90.1), forName: .weight)
        object.setAttributeValue(.null, forName: .data)

        object.setRelationIds(
            [.stable(.init(33)), .stable(.init(44))], forName: .children)

        let data = try object.objectDataForSave()

        XCTAssertGreaterThan(data.attributes.count, 3)
        XCTAssertNil(data.attributes[.pkId])
        XCTAssertNil(data.attributes[.objectId])
        XCTAssertNil(data.attributes[.action])
        XCTAssertNil(data.attributes[.saveId])
        XCTAssertEqual(data.attributes[.name], .text("suzuki"))
        XCTAssertEqual(data.attributes[.age], .integer(32))
        XCTAssertEqual(data.attributes[.weight], .real(90.1))
        XCTAssertEqual(data.attributes[.data], .null)

        XCTAssertEqual(data.relations.count, 1)
        XCTAssertEqual(data.relations[.children], [.stable(.init(33)), .stable(.init(44))])
    }

    @MainActor
    func testObjectIdOfSaveData() throws {
        // save_dataで返されるIdが同じか

        let model = TestUtils.makeModel0_0_1()
        let entityA = try XCTUnwrap(model.entities[.objectA])
        let entityB = try XCTUnwrap(model.entities[.objectB])

        let objectA = SyncedObject(entity: entityA)
        objectA.loadData(
            .init(
                id: .stable(.init(100)),
                values: .init(
                    pkId: 55, saveId: 555, action: .insert,
                    attributes: [.action: .updateAction], relations: [:])),
            force: false)

        let objectB1 = SyncedObject(entity: entityB)
        objectB1.loadData(
            .init(
                id: .stable(.init(200)),
                values: .init(
                    pkId: 66, saveId: 666, action: .insert,
                    attributes: [.action: .updateAction], relations: [:])),
            force: false)
        let objectB2 = SyncedObject(entity: entityB)
        objectB2.loadInsertionData()

        objectA.addRelationObject(objectB1, forName: .children)
        objectA.addRelationObject(objectB2, forName: .children)

        let saveDataA = try objectA.objectDataForSave()
        let saveDataB1 = try objectB1.objectDataForSave()
        let saveDataB2 = try objectB2.objectDataForSave()

        // stableがあればstableで返される
        let relationB1Id = try XCTUnwrap(saveDataA.relations[.children]?[0])
        XCTAssertEqual(relationB1Id.stable, saveDataB1.id.stable)

        // stableがなければtemporaryで返される
        let relationB2Id = try XCTUnwrap(saveDataA.relations[.children]?[1])
        XCTAssertEqual(relationB2Id.temporary, saveDataB2.id.temporary)
    }

    @MainActor
    func testChangeStatus() throws {
        let model = TestUtils.makeModel0_0_1()
        let entity = try XCTUnwrap(model.entities[.objectA])
        let object = SyncedObject(entity: entity)

        XCTAssertEqual(object.status, .cleared)

        object.loadInsertionData()

        XCTAssertEqual(object.status, .created)

        object.setAttributeValue(.integer(2), forName: .age)

        // まだ保存されていなければchangedではなくcreatedのまま
        XCTAssertEqual(object.status, .created)

        let temporaryId = try XCTUnwrap(object.id.temporary)
        let loadingData = LoadingObjectData(
            id: .both(stable: .init(1), temporary: temporaryId),
            values: .init(pkId: 1, saveId: 1, action: .insert, attributes: [:], relations: [:]))

        object.loadData(loadingData, force: false)

        XCTAssertEqual(object.status, .saved)

        object.setAttributeValue(.integer(2), forName: .age)

        XCTAssertEqual(object.status, .changed)

        object.setStatusToSaving()

        XCTAssertEqual(object.status, .saving)

        object.loadData(loadingData, force: false)

        XCTAssertEqual(object.status, .saved)
    }

    @MainActor
    func testPublisherAttributeUpdatedEvent() throws {
        let model = TestUtils.makeModel0_0_1()
        let entity = try XCTUnwrap(model.entities[.objectA])
        let object = SyncedObject(entity: entity)
        object.loadInsertionData()

        var received: [ObjectEvent] = []

        let canceller = object.publisher.sink { event in
            received.append(event)
        }

        XCTAssertEqual(received.count, 1)

        object.setAttributeValue(.text("test_value"), forName: .name)

        XCTAssertEqual(received.count, 2)

        switch received[1] {
        case let .attributeUpdated(_, name, value):
            XCTAssertEqual(name, .name)
            XCTAssertEqual(value, .text("test_value"))
        default:
            XCTFail()
            return
        }

        canceller.cancel()
    }

    @MainActor
    func testPublisherNoSendAttributeUpdatedWithSameValue() throws {
        let model = TestUtils.makeModel0_0_1()
        let entity = try XCTUnwrap(model.entities[.objectA])
        let object = SyncedObject(entity: entity)

        var received: [ObjectEvent] = []

        object.setAttributeValue(.text("test_value"), forName: .name)

        let canceller = object.publisher.sink { event in
            received.append(event)
        }

        XCTAssertEqual(received.count, 1)

        object.setAttributeValue(.text("test_value"), forName: .name)

        XCTAssertEqual(received.count, 1)

        canceller.cancel()
    }

    @MainActor
    func testPublisherRelationEvent() throws {
        let model = TestUtils.makeModel0_0_1()
        let entity = try XCTUnwrap(model.entities[.objectA])
        let object = SyncedObject(entity: entity)
        object.loadInsertionData()

        var received: [ObjectEvent] = []

        let canceller = object.publisher.sink { event in
            received.append(event)
        }

        XCTAssertEqual(received.count, 1)

        object.setRelationIds(
            [.stable(.init(10)), .stable(.init(20))], forName: .children)

        XCTAssertEqual(received.count, 2)

        switch received[1] {
        case let .relationReplaced(object, name):
            XCTAssertEqual(name, .children)
            XCTAssertEqual(
                object.relationIds(forName: .children), [.stable(.init(10)), .stable(.init(20))])
        default:
            XCTFail()
            return
        }

        object.addRelationId(.stable(.init(30)), forName: .children)

        XCTAssertEqual(received.count, 3)

        switch received[2] {
        case let .relationInserted(object, name, indices):
            XCTAssertEqual(name, .children)
            XCTAssertEqual(indices, [2])
            XCTAssertEqual(
                object.relationIds(forName: .children),
                [.stable(.init(10)), .stable(.init(20)), .stable(.init(30))])
        default:
            XCTFail()
            return
        }

        object.removeRelationId(.stable(.init(20)), forName: .children)

        XCTAssertEqual(received.count, 4)

        switch received[3] {
        case let .relationRemoved(object, name, indices):
            XCTAssertEqual(name, .children)
            XCTAssertEqual(indices, [1])
            XCTAssertEqual(
                object.relationIds(forName: .children),
                [.stable(.init(10)), .stable(.init(30))])
        default:
            XCTFail()
            return
        }

        object.removeAllRelations(forName: .children)

        XCTAssertEqual(received.count, 5)

        switch received[4] {
        case let .relationRemoved(object, name, indices):
            XCTAssertEqual(name, .children)
            XCTAssertEqual(indices, [0, 1])
            XCTAssertEqual(object.relationIds(forName: .children).count, 0)
        default:
            XCTFail()
            return
        }

        canceller.cancel()
    }

    @MainActor
    func testPublisherNoSendRelationIdsWithSameValue() throws {
        let model = TestUtils.makeModel0_0_1()
        let entity = try XCTUnwrap(model.entities[.objectA])
        let object = SyncedObject(entity: entity)

        object.setRelationIds([.stable(.init(55))], forName: .children)

        var received: [ObjectEvent] = []

        let canceller = object.publisher.sink { event in
            received.append(event)
        }

        XCTAssertEqual(received.count, 1)

        object.setRelationIds([.stable(.init(55))], forName: .children)

        XCTAssertEqual(received.count, 1)

        canceller.cancel()
    }

    @MainActor
    func testPublisherNoSendRelationIdsWithNonExistentValue() throws {
        let model = TestUtils.makeModel0_0_1()
        let entity = try XCTUnwrap(model.entities[.objectA])
        let object = SyncedObject(entity: entity)
        object.loadInsertionData()

        var received: [ObjectEvent] = []

        let canceller = object.publisher.sink { event in
            received.append(event)
        }

        XCTAssertEqual(received.count, 1)

        object.setRelationIds([.stable(.init(111))], forName: .children)

        XCTAssertEqual(received.count, 2)

        object.removeRelationId(.stable(.init(112)), forName: .children)

        XCTAssertEqual(received.count, 2)

        canceller.cancel()
    }

    @MainActor
    func testPublisherLoaded() throws {
        let model = TestUtils.makeModel0_0_1()
        let entity = try XCTUnwrap(model.entities[.objectA])
        let object = SyncedObject(entity: entity)

        var received: [ObjectEvent] = []

        let canceller = object.publisher.sink { event in
            received.append(event)
        }

        XCTAssertEqual(received.count, 1)

        let data = LoadingObjectData(
            id: .stable(.init(1)),
            values: .init(
                pkId: 55,
                saveId: 555,
                action: .insert,
                attributes: [
                    .age: .integer(10), .name: .text("name_val"),
                    .weight: .real(53.4),
                ],
                relations: [.children: [.stable(.init(55)), .stable(.init(66))]]))

        object.loadData(data, force: false)

        XCTAssertEqual(received.count, 2)

        switch received[1] {
        case let .loaded(object):
            XCTAssertEqual(object.id.stable, .init(1))
            XCTAssertEqual(object.attributeValue(forName: .age), .integer(10))
            XCTAssertEqual(object.attributeValue(forName: .name), .text("name_val"))
            XCTAssertEqual(object.attributeValue(forName: .weight), .real(53.4))
        default:
            XCTFail()
            return
        }

        canceller.cancel()
    }

    @MainActor
    func testClear() throws {
        let model = TestUtils.makeModel0_0_1()
        let entity = try XCTUnwrap(model.entities[.objectA])
        let object = SyncedObject(entity: entity)
        object.loadInsertionData()

        object.setAttributeValue(.integer(20), forName: .age)
        object.setAttributeValue(.text("test_name"), forName: .name)
        object.setRelationIds(
            [.stable(.init(23)), .stable(.init(45))], forName: .children)

        // 保存していないのでcreatedのまま
        XCTAssertEqual(object.status, .created)

        XCTAssertEqual(object.attributeValue(forName: .age), .integer(20))
        XCTAssertEqual(object.attributeValue(forName: .name), .text("test_name"))
        XCTAssertEqual(
            object.relationIds(forName: .children), [.stable(.init(23)), .stable(.init(45))])

        object.clearData()

        XCTAssertEqual(object.status, .cleared)
        XCTAssertEqual(object.attributeValue(forName: .age), .null)
        XCTAssertEqual(object.attributeValue(forName: .name), .null)
        XCTAssertEqual(object.relationIds(forName: .children).count, 0)
    }

    @MainActor
    func testPublisherCleared() throws {
        let model = TestUtils.makeModel0_0_1()
        let entity = try XCTUnwrap(model.entities[.objectA])
        let object = SyncedObject(entity: entity)
        object.loadInsertionData()

        object.setAttributeValue(.text("test_name"), forName: .name)
        object.setRelationIds(
            [.stable(.init(101)), .stable(.init(102))], forName: .children)

        XCTAssertEqual(object.status, .created)
        XCTAssertEqual(object.attributeValue(forName: .name), .text("test_name"))
        XCTAssertEqual(
            object.relationIds(forName: .children), [.stable(.init(101)), .stable(.init(102))])

        var received: [ObjectEvent] = []

        let canceller = object.publisher.sink { event in
            received.append(event)
        }

        XCTAssertEqual(received.count, 1)

        object.clearData()

        XCTAssertEqual(received.count, 2)

        switch received[1] {
        case let .cleared(object):
            XCTAssertEqual(object.status, .cleared)
            XCTAssertEqual(object.attributeValue(forName: .name), .null)
            XCTAssertEqual(object.relationIds(forName: .children).count, 0)
        default:
            XCTFail()
            return
        }

        canceller.cancel()
    }

    @MainActor
    func testPublisherFetchedEvent() throws {
        let model = TestUtils.makeModel0_0_1()
        let entity = try XCTUnwrap(model.entities[.objectA])
        let object = SyncedObject(entity: entity)

        var received: [ObjectEvent] = []

        let canceller = object.publisher.sink { event in
            received.append(event)
        }

        switch received[0] {
        case .fetched:
            break
        default:
            XCTFail()
            return
        }

        canceller.cancel()
    }

    @MainActor
    func testTypedDefault() throws {
        let model = TestUtils.makeModel0_0_2()
        let entity = try XCTUnwrap(model.entities[.objectA])
        let object = SyncedObject(entity: entity)
        object.loadInsertionData()

        let typedObject = try object.typed(ObjectA.self)

        XCTAssertNil(typedObject.id.rawId.stable)
        XCTAssertNotNil(typedObject.id.rawId.temporary)

        XCTAssertEqual(typedObject.attributes.age, 10)
        XCTAssertEqual(typedObject.attributes.name, "default_value")
        XCTAssertEqual(typedObject.attributes.weight, 65.4)
        XCTAssertEqual(typedObject.attributes.tall, 172.4)
        XCTAssertNil(typedObject.attributes.data)

        XCTAssertEqual(typedObject.relations.children.count, 0)
        XCTAssertNil(typedObject.relations.friend)
    }

    @MainActor
    func testTypedEdited() throws {
        let model = TestUtils.makeModel0_0_2()
        let entity = try XCTUnwrap(model.entities[.objectA])
        let object = SyncedObject(entity: entity)
        object.loadInsertionData()

        object.setAttributeValue(.integer(11), forName: .age)
        object.setAttributeValue(.text("name_value"), forName: .name)
        object.setAttributeValue(.real(67.8), forName: .weight)
        object.setAttributeValue(.null, forName: .tall)
        object.setAttributeValue(.blob(Data([0, 1])), forName: .data)

        object.setRelationIds(
            [.stable(.init(100)), .stable(.init(101))], forName: .children)
        object.setRelationIds([.stable(.init(200))], forName: .friend)

        let typedObject = try object.typed(ObjectA.self)

        XCTAssertNil(typedObject.id.rawId.stable)
        XCTAssertNotNil(typedObject.id.rawId.temporary)

        XCTAssertEqual(typedObject.attributes.age, 11)
        XCTAssertEqual(typedObject.attributes.name, "name_value")
        XCTAssertEqual(typedObject.attributes.weight, 67.8)
        XCTAssertNil(typedObject.attributes.tall)
        XCTAssertEqual(typedObject.attributes.data, Data([0, 1]))

        XCTAssertEqual(
            typedObject.relations.children,
            [.init(rawId: .stable(.init(100))), .init(rawId: .stable(.init(101)))])
        XCTAssertEqual(typedObject.relations.friend, .init(rawId: .stable(.init(200))))
    }

    @MainActor
    func testTypedRemoved() throws {
        let model = TestUtils.makeModel0_0_2()
        let entity = try XCTUnwrap(model.entities[.objectA])
        let object = SyncedObject(entity: entity)
        object.loadInsertionData()

        object.remove()

        XCTAssertThrowsError(try object.typed(ObjectA.self))
    }

    @MainActor
    func testUpdateByTyped() throws {
        let model = TestUtils.makeModel0_0_2()
        let entity = try XCTUnwrap(model.entities[.objectA])
        let object = SyncedObject(entity: entity)
        object.loadInsertionData()

        var typed = try object.typed(ObjectA.self)

        typed.attributes.age = 12
        typed.attributes.name = "typed_name_value"
        typed.attributes.weight = 78.9
        typed.attributes.tall = 123.45
        typed.attributes.data = Data([10, 11, 12])

        typed.relations.children = [
            .init(rawId: .stable(.init(1000))), .init(rawId: .stable(.init(1001))),
        ]
        typed.relations.friend = .init(rawId: .stable(.init(2000)))

        try object.updateByTyped(typed)

        XCTAssertEqual(object.attributeValue(forName: .age), .integer(12))
        XCTAssertEqual(object.attributeValue(forName: .name), .text("typed_name_value"))
        XCTAssertEqual(object.attributeValue(forName: .weight), .real(78.9))
        XCTAssertEqual(object.attributeValue(forName: .tall), .real(123.45))
        XCTAssertEqual(object.attributeValue(forName: .data), .blob(Data([10, 11, 12])))

        XCTAssertEqual(object.relationIds[.children], [.stable(.init(1000)), .stable(.init(1001))])
        XCTAssertEqual(object.relationIds[.friend], [.stable(.init(2000))])
    }
}
