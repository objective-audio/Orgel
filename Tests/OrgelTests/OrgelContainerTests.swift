import XCTest

@testable import Orgel

final class DatabaseContainerTests: XCTestCase {
    private let uuid: UUID = .init()

    override func setUpWithError() throws {
        TestUtils.deleteFile(uuid: uuid)
    }

    override func tearDownWithError() throws {
        TestUtils.deleteFile(uuid: uuid)
    }

    @MainActor
    func testInit() async throws {
        let url = TestUtils.databaseUrl(uuid: uuid)
        let model = TestUtils.makeModel0_0_0()
        let data = OrgelData(
            info: .init(version: try .init("0.0.1"), currentSaveId: 0, lastSaveId: 0),
            model: model)
        let executor = OrgelExecutor(model: model, data: data, sqliteExecutor: .init(url: url))
        let database = OrgelContainer(executor: executor, model: model, data: data)

        XCTAssertEqual(database.data.info.version.stringValue, "0.0.1")
        XCTAssertEqual(database.data.info.currentSaveId, 0)
        XCTAssertEqual(database.data.info.lastSaveId, 0)
    }

    @MainActor
    func testMakeWithSetup() async throws {
        let url = TestUtils.databaseUrl(uuid: uuid)
        let model = TestUtils.makeModel0_0_1()

        let database = try await OrgelContainer.makeWithSetup(url: url, model: model)

        XCTAssertEqual(database.data.info.version.stringValue, "0.0.1")
        XCTAssertEqual(database.data.info.currentSaveId, 0)
        XCTAssertEqual(database.data.info.lastSaveId, 0)
    }

    @MainActor
    func testSetupMigration() async throws {
        do {
            let model = TestUtils.makeModel0_0_1()
            let (_, executor) = try await TestUtils.makeDatabaseWithSetup(
                uuid: uuid, model: model)

            guard await executor.open() else {
                XCTFail()
                return
            }

            try await executor.beginTransaction()

            try await executor.executeUpdate(
                .insert(
                    table: .objectA, columnNames: [.age, .name, .weight]),
                parameters: [.age: .integer(2), .name: .text("xyz"), .weight: .real(451.2)]
            )

            try await executor.executeUpdate(
                .insert(table: .objectB, columnNames: [.fullname]),
                parameters: [.fullname: .text("qwerty")]
            )

            let optionA = SQLSelect(table: .objectA, field: .column(.objectId))
            let selectedAValues = try await executor.select(optionA)
            let sourceObjectId = try XCTUnwrap(selectedAValues[0][.objectId])

            let optionB = SQLSelect(table: .objectB, field: .column(.objectId))
            let selectedBValues = try await executor.select(optionB)
            let targetObjectId = try XCTUnwrap(selectedBValues[0][.objectId])

            try await executor.executeUpdate(
                .insert(
                    table: .init("rel_ObjectA_children"),
                    columnNames: [.sourceObjectId, .targetObjectId]),
                parameters: [
                    .sourceObjectId: sourceObjectId,
                    .targetObjectId: targetObjectId,
                ]
            )

            let saveIdValue = SQLValue.integer(100)

            try await executor.executeUpdate(
                .update(
                    table: OrgelInfo.table, columnNames: [.currentSaveId, .lastSaveId]),
                parameters: [
                    .currentSaveId: saveIdValue,
                    .lastSaveId: saveIdValue,
                ]
            )

            try await executor.commit()

            await executor.close()
        }

        do {
            let model = TestUtils.makeModel0_0_2()
            let (_, executor) = try await TestUtils.makeDatabaseWithSetup(
                uuid: uuid, model: model)

            guard await executor.open() else {
                XCTFail()
                return
            }

            let infoTableExists = await executor.tableExists(OrgelInfo.table)
            XCTAssertTrue(infoTableExists)

            let infoValues = try await executor.select(.init(table: OrgelInfo.table))
            XCTAssertEqual(infoValues.count, 1)
            XCTAssertEqual(infoValues[0][.version], .text("0.0.2"))
            XCTAssertEqual(infoValues[0][.currentSaveId], .integer(100))
            XCTAssertEqual(infoValues[0][.lastSaveId], .integer(100))

            let objectAExists = await executor.tableExists(.objectA)
            XCTAssertTrue(objectAExists)

            let objectAValues = try await executor.select(.init(table: .objectA))
            XCTAssertEqual(objectAValues.count, 1)

            let objectA = objectAValues[0]
            XCTAssertEqual(objectA[.age], .integer(2))
            XCTAssertEqual(objectA[.name], .text("xyz"))
            XCTAssertEqual(objectA[.weight], .real(451.2))

            let objectBExists = await executor.tableExists(.objectB)
            XCTAssertTrue(objectBExists)

            let objectBValues = try await executor.select(.init(table: .objectB))
            XCTAssertEqual(objectBValues.count, 1)

            let objectB = objectBValues[0]
            XCTAssertEqual(objectB[.fullname], .text("qwerty"))

            let objectCExists = await executor.tableExists(.objectC)
            XCTAssertTrue(objectCExists)

            let objectCValues = try await executor.select(.init(table: .objectC))
            XCTAssertEqual(objectCValues.count, 0)

            let relationExists = await executor.tableExists(.init("rel_ObjectA_children"))
            XCTAssertTrue(relationExists)

            let relationValues = try await executor.select(
                .init(table: .init("rel_ObjectA_children"))
            )
            XCTAssertEqual(relationValues.count, 1)

            let sourceObjectId = try XCTUnwrap(objectA[.objectId])
            let targetObjectId = try XCTUnwrap(objectB[.objectId])

            let relation = relationValues[0]
            XCTAssertEqual(relation[.sourceObjectId], sourceObjectId)
            XCTAssertEqual(relation[.targetObjectId], targetObjectId)

            let objectANameIndexExists = await executor.indexExists(.init("ObjectA_name"))
            let objectAOthersIndexExists = await executor.indexExists(.init("ObjectA_others"))
            let objectBNameIndexExists = await executor.indexExists(.init("ObjectB_name"))
            XCTAssertTrue(objectANameIndexExists)
            XCTAssertTrue(objectAOthersIndexExists)
            XCTAssertTrue(objectBNameIndexExists)

            await executor.close()
        }
    }

    @MainActor
    func testCreateObject() async throws {
        let model = TestUtils.makeModel0_0_1()
        let (database, _) = try await TestUtils.makeDatabaseWithSetup(uuid: uuid, model: model)

        XCTAssertFalse(database.data.hasCreatedObjects)
        XCTAssertEqual(database.data.createdObjectCount(entityName: .objectA), 0)

        var objects: [SyncedObject] = []

        objects.append(database.data.createObject(entityName: .objectA))
        objects.append(database.data.createObject(entityName: .objectA))

        XCTAssertTrue(database.data.hasCreatedObjects)
        XCTAssertEqual(database.data.createdObjectCount(entityName: .objectA), 2)

        for object in objects {
            XCTAssertEqual(object.status, .created)
            XCTAssertTrue(object.id.isTemporary)
            XCTAssertEqual(object.action, .insert)
            XCTAssertEqual(object.attributeValue(forName: .name), .text("default_value"))
            XCTAssertEqual(object.attributeValue(forName: .age), .integer(10))
            XCTAssertEqual(object.attributeValue(forName: .weight), .real(65.4))
        }

        objects[0].setAttributeValue(.text("test_name_0_created"), forName: .name)
        objects[1].setAttributeValue(.text("test_name_1_created"), forName: .name)

        for object in objects {
            XCTAssertEqual(object.status, .created)
        }

        let savedObjects = try await database.executor.save()

        XCTAssertEqual(database.data.info.currentSaveId, 1)
        XCTAssertFalse(database.data.hasCreatedObjects)
        XCTAssertEqual(database.data.createdObjectCount(entityName: .objectA), 0)

        let aObjects = try XCTUnwrap(savedObjects[.objectA]?.objects)
        XCTAssertEqual(aObjects.count, 2)

        for (index, object) in objects.enumerated() {
            let savedObject = try XCTUnwrap(aObjects[object.id])

            XCTAssertEqual(ObjectIdentifier(savedObject), ObjectIdentifier(object))
            XCTAssertNotNil(savedObject.id.stable)
            XCTAssertNotNil(savedObject.id.temporary)

            XCTAssertEqual(savedObject.status, .saved)
            XCTAssertEqual(savedObject.action, .insert)
            XCTAssertEqual(savedObject.attributeValue(forName: .age), .integer(10))
            XCTAssertEqual(savedObject.attributeValue(forName: .weight), .real(65.4))

            XCTAssertEqual(savedObject.saveId, 1)

            switch index {
            case 0:
                XCTAssertEqual(
                    savedObject.attributeValue(forName: .name), .text("test_name_0_created")
                )
            case 1:
                XCTAssertEqual(
                    savedObject.attributeValue(forName: .name), .text("test_name_1_created")
                )
            default:
                XCTFail()
            }
        }
    }

    @MainActor
    func testCreateTypedObject() async throws {
        let model = TestUtils.makeModel0_0_2()
        let (database, _) = try await TestUtils.makeDatabaseWithSetup(uuid: uuid, model: model)

        XCTAssertFalse(database.data.hasCreatedObjects)
        XCTAssertEqual(database.data.createdObjectCount(entityName: .objectA), 0)

        var objects: [ObjectA] = []

        objects.append(try database.data.createObject(ObjectA.self))
        objects.append(try database.data.createObject(ObjectA.self))

        for object in objects {
            XCTAssertTrue(object.id.rawId.isTemporary)
            XCTAssertEqual(object.attributes.name, "default_value")
            XCTAssertEqual(object.attributes.age, 10)
            XCTAssertEqual(object.attributes.weight, 65.4)
            XCTAssertEqual(object.attributes.tall, 172.4)
            XCTAssertNil(object.attributes.data)

            XCTAssertEqual(object.relations.children.count, 0)
            XCTAssertNil(object.relations.friend)
        }
    }

    @MainActor
    func testCreateAndSaveObjects() async throws {
        let model = TestUtils.makeModel0_0_1()
        let (database, _) = try await TestUtils.makeDatabaseWithSetup(uuid: uuid, model: model)

        var objects = [
            database.data.createObject(entityName: .objectA),
            database.data.createObject(entityName: .objectA),
        ]

        objects[0].setAttributeValue(.text("test_name_0_created"), forName: .name)
        objects[1].setAttributeValue(.text("test_name_1_created"), forName: .name)

        XCTAssertTrue(database.data.hasCreatedObjects)
        XCTAssertEqual(database.data.createdObjectCount(entityName: .objectA), 2)

        let _ = try await database.executor.save()

        XCTAssertFalse(database.data.hasCreatedObjects)

        XCTAssertEqual(objects[0].status, .saved)
        XCTAssertEqual(objects[1].status, .saved)
        XCTAssertNotNil(
            database.data.cachedOrCreatedObject(
                entityName: .objectA, objectId: objects[0].id))
        XCTAssertNotNil(
            database.data.cachedOrCreatedObject(
                entityName: .objectA, objectId: objects[1].id))

        objects[0].setAttributeValue(.text("test_name_0_saved"), forName: .name)
        objects[0].setAttributeValue(.integer(0), forName: .age)
        objects[1].setAttributeValue(.text("test_name_1_saved"), forName: .name)
        objects[1].setAttributeValue(.integer(1), forName: .age)

        XCTAssertEqual(objects[0].status, .changed)
        XCTAssertEqual(objects[1].status, .changed)

        XCTAssertTrue(database.data.hasChangedObjects)
        XCTAssertEqual(database.data.changedObjectCount(entityName: .objectA), 2)
        XCTAssertFalse(database.data.hasCreatedObjects)
        XCTAssertEqual(database.data.createdObjectCount(entityName: .objectA), 0)

        objects.append(database.data.createObject(entityName: .objectA))
        objects.append(database.data.createObject(entityName: .objectA))

        objects[2].setAttributeValue(.text("test_name_2_created"), forName: .name)
        objects[2].setAttributeValue(.integer(2), forName: .age)
        objects[3].setAttributeValue(.text("test_name_3_created"), forName: .name)
        objects[3].setAttributeValue(.integer(3), forName: .age)

        XCTAssertTrue(database.data.hasCreatedObjects)

        let _ = try await database.executor.save()

        XCTAssertEqual(
            objects[0].attributeValue(forName: .name), .text("test_name_0_saved"))
        XCTAssertEqual(
            objects[1].attributeValue(forName: .name), .text("test_name_1_saved"))
        XCTAssertEqual(
            objects[2].attributeValue(forName: .name), .text("test_name_2_created"))
        XCTAssertEqual(
            objects[3].attributeValue(forName: .name), .text("test_name_3_created"))

        XCTAssertEqual(objects[0].status, .saved)
        XCTAssertEqual(objects[1].status, .saved)
        XCTAssertEqual(objects[2].status, .saved)
        XCTAssertEqual(objects[3].status, .saved)

        XCTAssertNotNil(objects[0].id.stable)
        XCTAssertNotNil(objects[1].id.stable)
        XCTAssertNotNil(objects[2].id.stable)
        XCTAssertNotNil(objects[3].id.stable)

        let fetchedObjects = try await database.executor.fetchReadOnlyObjects(
            .init(selects: [
                .init(
                    table: .objectA, columnOrders: [.init(name: .age, order: .ascending)])
            ]))

        XCTAssertEqual(fetchedObjects.count, 1)

        let fetchedAObjects = try XCTUnwrap(fetchedObjects[.objectA])

        XCTAssertEqual(fetchedAObjects.objects.count, 4)
        XCTAssertEqual(
            fetchedAObjects.object(at: 0)?.attributeValue(forName: .name),
            .text("test_name_0_saved"))
        XCTAssertEqual(
            fetchedAObjects.object(at: 1)?.attributeValue(forName: .name),
            .text("test_name_1_saved"))
        XCTAssertEqual(
            fetchedAObjects.object(at: 2)?.attributeValue(forName: .name),
            .text("test_name_2_created"))
        XCTAssertEqual(
            fetchedAObjects.object(at: 3)?.attributeValue(forName: .name),
            .text("test_name_3_created"))
    }

    @MainActor
    func testSetRelationToTemporaryObject() async throws {
        // temporaryなオブジェクトのrelationにtemporaryなオブジェクトをセットして保存するテスト

        let model = TestUtils.makeModel0_0_1()
        let (database, _) = try await TestUtils.makeDatabaseWithSetup(uuid: uuid, model: model)

        let objectA = database.data.createObject(entityName: .objectA)
        let objectB1 = database.data.createObject(entityName: .objectB)
        let objectB2 = database.data.createObject(entityName: .objectB)

        XCTAssertTrue(objectA.id.isTemporary)
        XCTAssertTrue(objectB1.id.isTemporary)
        XCTAssertTrue(objectB2.id.isTemporary)

        objectA.addRelationObject(objectB1, forName: .children)
        objectA.addRelationObject(objectB2, forName: .children)

        let savedObjects = try await database.executor.save()

        XCTAssertTrue(objectA.id.isStable)
        XCTAssertTrue(objectB1.id.isStable)
        XCTAssertTrue(objectB2.id.isStable)

        XCTAssertEqual(objectA.relationIds(forName: .children)[0], objectB1.id)
        XCTAssertEqual(objectA.relationIds(forName: .children)[1], objectB2.id)

        let savedObjectA = try XCTUnwrap(savedObjects[.objectA]?.objects.first?.value)
        XCTAssertEqual(savedObjectA.id, objectA.id)
        let savedBObjects = try XCTUnwrap(savedObjects[.objectB]?.objects)
        XCTAssertNotNil(savedBObjects[objectB1.id])
        XCTAssertNotNil(savedBObjects[objectB2.id])
    }

    @MainActor
    func testSetTemporaryRelationToSavedObject() async throws {
        // stableなオブジェクトのrelationにtemporaryなオブジェクトをセットして保存するテスト
        let model = TestUtils.makeModel0_0_1()
        let (database, _) = try await TestUtils.makeDatabaseWithSetup(uuid: uuid, model: model)

        let objectA = database.data.createObject(entityName: .objectA)

        let _ = try await database.executor.save()

        XCTAssertTrue(objectA.id.isStable)

        let objectB = database.data.createObject(entityName: .objectB)

        objectA.addRelationObject(objectB, forName: .children)

        let _ = try await database.executor.save()

        XCTAssertTrue(objectA.relationIds(forName: .children)[0].isStable)
        XCTAssertEqual(
            database.data.relationObject(sourceObject: objectA, relationName: .children, at: 0)?
                .id,
            objectB.id)
    }

    @MainActor
    func testObjectRelationObjects() async throws {
        let model = TestUtils.makeModel0_0_1()
        let (database, _) = try await TestUtils.makeDatabaseWithSetup(uuid: uuid, model: model)

        let objectA = database.data.createObject(entityName: .objectA)
        let objectB1 = database.data.createObject(entityName: .objectB)
        let objectB2 = database.data.createObject(entityName: .objectB)
        let objectB3 = database.data.createObject(entityName: .objectB)

        let _ = try await database.executor.save()

        objectA.addRelationObject(objectB1, forName: .children)
        objectA.addRelationObject(objectB2, forName: .children)
        objectA.addRelationObject(objectB3, forName: .children)

        let relationObjects = database.data.relationObjects(
            sourceObject: objectA, relationName: .children)

        XCTAssertEqual(relationObjects.count, 3)

        XCTAssertNotNil(relationObjects[0])
        XCTAssertNotNil(relationObjects[1])
        XCTAssertNotNil(relationObjects[2])

        XCTAssertEqual(relationObjects[0]?.id.stable, objectB1.id.stable)
        XCTAssertEqual(relationObjects[1]?.id.stable, objectB2.id.stable)
        XCTAssertEqual(relationObjects[2]?.id.stable, objectB3.id.stable)
    }

    @MainActor
    func testInsertSyncedObjectsByCount() async throws {
        let model = TestUtils.makeModel0_0_1()
        let (database, _) = try await TestUtils.makeDatabaseWithSetup(uuid: uuid, model: model)

        XCTAssertEqual(database.data.info.currentSaveId, 0)
        XCTAssertEqual(database.data.info.lastSaveId, 0)

        // database内のキャッシュから取得するテストをしたいので解放されないようにする
        var retainedObjects: [SyncedObject] = []

        do {
            let insertedData = try await database.executor.insertSyncedObjects(counts: [
                .objectA: 3
            ])
            let objects = try XCTUnwrap(insertedData[.objectA]?.array)

            XCTAssertEqual(objects.count, 3)

            XCTAssertEqual(objects[0].id, .stable(.init(1)))
            XCTAssertEqual(objects[1].id, .stable(.init(2)))
            XCTAssertEqual(objects[2].id, .stable(.init(3)))

            XCTAssertEqual(objects[0].action, .insert)
            XCTAssertEqual(objects[1].action, .insert)
            XCTAssertEqual(objects[2].action, .insert)

            retainedObjects.append(contentsOf: objects)
        }

        XCTAssertEqual(database.data.info.currentSaveId, 1)
        XCTAssertEqual(database.data.info.lastSaveId, 1)

        do {
            let insertedData = try await database.executor.insertSyncedObjects(counts: [
                .objectA: 1
            ])
            let objects = try XCTUnwrap(insertedData[.objectA]?.array)

            XCTAssertEqual(objects.count, 1)
            XCTAssertEqual(objects[0].id, .stable(.init(4)))
            XCTAssertEqual(objects[0].action, .insert)

            retainedObjects.append(contentsOf: objects)
        }

        XCTAssertEqual(database.data.info.currentSaveId, 2)
        XCTAssertEqual(database.data.info.lastSaveId, 2)

        let object = try XCTUnwrap(
            database.data.cachedOrCreatedObject(
                entityName: .objectA, objectId: .stable(.init(1))))
        XCTAssertEqual(object.id.stable?.rawValue, 1)

        XCTAssertNil(
            database.data.cachedOrCreatedObject(
                entityName: .objectA, objectId: .stable(.init(5))))
    }

    @MainActor
    func testInsertSyncedObjectsByValues() async throws {
        let model = TestUtils.makeModel0_0_1()
        let (database, _) = try await TestUtils.makeDatabaseWithSetup(uuid: uuid, model: model)

        XCTAssertEqual(database.data.info.currentSaveId, 0)

        let insertedData = try await database.executor.insertSyncedObjects(values: [
            .objectA: [
                [.name: .text("test_name_1"), .age: .integer(43)],
                [.name: .text("test_name_2"), .age: .integer(67)],
            ]
        ])

        let objects = try XCTUnwrap(insertedData[.objectA]?.array)

        XCTAssertEqual(objects.count, 2)
        XCTAssertEqual(objects[0].attributeValue(forName: .name), .text("test_name_1"))
        XCTAssertEqual(objects[0].attributeValue(forName: .age), .integer(43))
        XCTAssertEqual(objects[1].attributeValue(forName: .name), .text("test_name_2"))
        XCTAssertEqual(objects[1].attributeValue(forName: .age), .integer(67))

        XCTAssertEqual(database.data.info.currentSaveId, 1)
    }

    @MainActor
    func testInsertManyEntityObjects() async throws {
        let model = TestUtils.makeModel0_0_2()
        let (database, _) = try await TestUtils.makeDatabaseWithSetup(uuid: uuid, model: model)

        let insertedData = try await database.executor.insertSyncedObjects(counts: [
            .objectA: 3, .objectB: 5,
        ])

        XCTAssertEqual(insertedData.count, 2)

        let insertedAObjects = try XCTUnwrap(insertedData[.objectA]?.objects)

        XCTAssertEqual(insertedAObjects.count, 3)

        let insertedBObjects = try XCTUnwrap(insertedData[.objectB]?.objects)

        XCTAssertEqual(insertedBObjects.count, 5)
    }

    @MainActor
    func testInsertWithDelete() async throws {
        let model = TestUtils.makeModel0_0_2()
        let (database, executor) = try await TestUtils.makeDatabaseWithSetup(
            uuid: uuid, model: model)

        XCTAssertEqual(database.data.info.currentSaveId, 0)
        XCTAssertEqual(database.data.info.lastSaveId, 0)

        do {
            let insertedData = try await database.executor.insertSyncedObjects(counts: [
                .objectA: 1
            ])

            let objectA = try XCTUnwrap(insertedData[.objectA]?.objects.first?.value)
            objectA.setAttributeValue(.text("first_name_value"), forName: .name)
        }

        let _ = try await database.executor.save()

        XCTAssertEqual(database.data.info.currentSaveId, 2)

        do {
            let insertedData = try await database.executor.insertSyncedObjects(counts: [
                .objectA: 1
            ])

            let objectA = try XCTUnwrap(insertedData[.objectA]?.objects.first?.value)
            objectA.setAttributeValue(.text("second_name_value"), forName: .name)
        }

        let _ = try await database.executor.save()

        XCTAssertEqual(database.data.info.currentSaveId, 4)

        let _ = try await database.executor.revert(saveId: 2)

        XCTAssertEqual(database.data.info.currentSaveId, 2)

        do {
            _ = try await database.executor.insertSyncedObjects(counts: [
                .objectA: 1
            ])
        }

        do {
            guard await executor.open() else {
                XCTFail()
                return
            }

            let selectedValues = try await executor.select(
                .init(table: .objectA)
            )

            await executor.close()

            XCTAssertEqual(selectedValues.count, 3)

            for values in selectedValues {
                XCTAssertNotEqual(values[.name], .text("second_name_value"))
            }
        }
    }

    @MainActor
    func testFetchMutableObjects() async throws {
        let model = TestUtils.makeModel0_0_1()
        let (database, _) = try await TestUtils.makeDatabaseWithSetup(uuid: uuid, model: model)

        let insertedData = try await database.executor.insertSyncedObjects(counts: [
            .objectA: 3, .objectB: 2,
        ])

        let aObjects = try XCTUnwrap(insertedData[.objectA]?.array)
        XCTAssertEqual(aObjects.count, 3)
        XCTAssertEqual(aObjects[0].id.stable?.rawValue, 1)
        XCTAssertEqual(aObjects[1].id.stable?.rawValue, 2)
        XCTAssertEqual(aObjects[2].id.stable?.rawValue, 3)
        XCTAssertEqual(aObjects[0].attributeValue(forName: .name), .text("default_value"))
        XCTAssertEqual(aObjects[1].attributeValue(forName: .name), .text("default_value"))
        XCTAssertEqual(aObjects[2].attributeValue(forName: .name), .text("default_value"))

        let bObjects = try XCTUnwrap(insertedData[.objectB]?.array)
        XCTAssertEqual(bObjects[0].id.stable?.rawValue, 1)
        XCTAssertEqual(bObjects[1].id.stable?.rawValue, 2)
        XCTAssertEqual(bObjects[0].attributeValue(forName: .fullname), .null)
        XCTAssertEqual(bObjects[1].attributeValue(forName: .fullname), .null)

        XCTAssertEqual(database.data.info.currentSaveId, 1)
        XCTAssertEqual(database.data.info.lastSaveId, 1)

        aObjects[1].setAttributeValue(.text("value_1"), forName: .name)
        aObjects[1].addRelationId(bObjects[0].id, forName: .children)

        let _ = try await database.executor.save()

        XCTAssertEqual(database.data.info.currentSaveId, 2)
        XCTAssertEqual(database.data.info.lastSaveId, 2)

        do {
            let fetchedObjects = try await database.executor.fetchSyncedObjects(
                .init(selects: [.init(table: .objectA)]))

            let fetchedAObjects = try XCTUnwrap(fetchedObjects[.objectA])
            XCTAssertEqual(fetchedAObjects.objects.count, 3)
            let fetchedAObject0 = try XCTUnwrap(fetchedAObjects.object(at: 0))
            let fetchedAObject1 = try XCTUnwrap(fetchedAObjects.object(at: 1))
            let fetchedAObject2 = try XCTUnwrap(fetchedAObjects.object(at: 2))
            XCTAssertEqual(fetchedAObject0.id.stable?.rawValue, 1)
            XCTAssertEqual(fetchedAObject1.id.stable?.rawValue, 3)
            XCTAssertEqual(fetchedAObject2.id.stable?.rawValue, 2)
            XCTAssertEqual(fetchedAObject0.attributeValue(forName: .name), .text("default_value"))
            XCTAssertEqual(fetchedAObject1.attributeValue(forName: .name), .text("default_value"))
            XCTAssertEqual(fetchedAObject2.attributeValue(forName: .name), .text("value_1"))
            XCTAssertEqual(fetchedAObject2.relationIds[.children]?.count, 1)
            XCTAssertEqual(fetchedAObject2.relationIds(forName: .children).count, 1)
            XCTAssertEqual(fetchedAObject2.relationIds(forName: .children)[0].stable?.rawValue, 1)
        }

        aObjects[2].setAttributeValue(.text("value_2"), forName: .name)
        aObjects[2].removeAllRelations(forName: .children)
        aObjects[2].addRelationId(bObjects[1].id, forName: .children)
        aObjects[2].addRelationId(bObjects[0].id, forName: .children)

        let _ = try await database.executor.save()

        XCTAssertEqual(database.data.info.currentSaveId, 3)
        XCTAssertEqual(database.data.info.lastSaveId, 3)

        do {
            let fetchedObjects = try await database.executor.fetchSyncedObjects(
                .init(selects: [
                    .init(
                        table: .objectA,
                        where: .expression(.compare(.name, .like, .name(.name))),
                        parameters: [.init("name"): .text("value_%")],
                        columnOrders: [.init(name: .objectId, order: .descending)],
                        limitRange: .init(location: 0, length: 3))
                ]))

            let fetchedAObjects = try XCTUnwrap(fetchedObjects[.objectA])
            XCTAssertEqual(fetchedAObjects.objects.count, 2)

            let fetchedAObject0 = try XCTUnwrap(fetchedAObjects.object(at: 0))
            let fetchedAObject1 = try XCTUnwrap(fetchedAObjects.object(at: 1))
            XCTAssertEqual(fetchedAObject0.id.stable?.rawValue, 3)
            XCTAssertEqual(
                fetchedAObject0.attributeValue(forName: .name), .text("value_2"))

            XCTAssertEqual(fetchedAObject1.id.stable?.rawValue, 2)
            XCTAssertEqual(fetchedAObject1.attributeValue(forName: .name), .text("value_1"))

            XCTAssertEqual(fetchedAObject0.relationIds.count, 1)
            XCTAssertEqual(fetchedAObject0.relationIds(forName: .children).count, 2)
            XCTAssertEqual(
                fetchedAObject0.relationIds(forName: .children)[0].stable?.rawValue, 2)
            XCTAssertEqual(
                fetchedAObject0.relationIds(forName: .children)[1].stable?.rawValue, 1)
        }
    }

    @MainActor
    func testFetchMutableObjectsOfRelations() async throws {
        let model = TestUtils.makeModel0_0_2()
        let (database, _) = try await TestUtils.makeDatabaseWithSetup(uuid: uuid, model: model)

        do {
            let objects = try await database.executor.insertSyncedObjects(counts: [
                .objectA: 1, .objectB: 1, .objectC: 1,
            ])

            XCTAssertEqual(objects.count, 3)

            let aObjects = try XCTUnwrap(objects[.objectA]?.array)
            let bObjects = try XCTUnwrap(objects[.objectB]?.array)
            let cObjects = try XCTUnwrap(objects[.objectC]?.array)

            XCTAssertEqual(aObjects.count, 1)
            XCTAssertEqual(bObjects.count, 1)
            XCTAssertEqual(cObjects.count, 1)

            let objectA = aObjects[0]
            let objectB = bObjects[0]
            let objectC = cObjects[0]

            objectA.addRelationObject(objectB, forName: .children)
            objectA.addRelationObject(objectC, forName: .friend)

            objectB.addRelationObject(objectA, forName: .parent)
            objectC.addRelationObject(objectA, forName: .friend)
        }

        do {
            let objects = try await database.executor.save()

            XCTAssertEqual(objects.count, 3)

            let aObjects = try XCTUnwrap(objects[.objectA])
            let bObjects = try XCTUnwrap(objects[.objectB])
            let cObjects = try XCTUnwrap(objects[.objectC])

            XCTAssertEqual(aObjects.objects.count, 1)
            XCTAssertEqual(bObjects.objects.count, 1)
            XCTAssertEqual(cObjects.objects.count, 1)

            let objectA = try XCTUnwrap(aObjects.objects.first?.value)
            let objectB = try XCTUnwrap(bObjects.objects.first?.value)
            let objectC = try XCTUnwrap(cObjects.objects.first?.value)

            XCTAssertEqual(objectA.relationIds[.children]?.count, 1)
            XCTAssertEqual(
                database.data.relationObject(sourceObject: objectA, relationName: .children, at: 0)?
                    .id,
                objectB.id
            )
            XCTAssertEqual(objectA.relationIds(forName: .children)[0].stable?.rawValue, 1)

            XCTAssertEqual(objectA.relationIds[.friend]?.count, 1)
            XCTAssertEqual(
                database.data.relationObject(sourceObject: objectA, relationName: .friend, at: 0)?
                    .id,
                objectC.id
            )
            XCTAssertEqual(objectA.relationIds(forName: .friend)[0].stable?.rawValue, 1)

            XCTAssertEqual(objectB.relationIds[.parent]?.count, 1)
            XCTAssertEqual(
                database.data.relationObject(sourceObject: objectB, relationName: .parent, at: 0)?
                    .id,
                objectA.id
            )

            XCTAssertEqual(objectC.relationIds[.friend]?.count, 1)
            XCTAssertEqual(
                database.data.relationObject(sourceObject: objectC, relationName: .friend, at: 0)?
                    .id,
                objectA.id
            )
        }

        XCTAssertNil(
            database.data.cachedOrCreatedObject(entityName: .objectA, objectId: .stable(.init(1))))
        XCTAssertNil(
            database.data.cachedOrCreatedObject(entityName: .objectB, objectId: .stable(.init(1))))
        XCTAssertNil(
            database.data.cachedOrCreatedObject(entityName: .objectC, objectId: .stable(.init(1))))

        let objectA: SyncedObject

        do {
            let objects = try await database.executor.fetchSyncedObjects(
                .init(selects: [.init(table: .objectA)]))
            objectA = try XCTUnwrap(objects[.objectA]?.object(at: 0))

            XCTAssertEqual(objectA.relationIds[.children]?.count, 1)
            XCTAssertNil(
                database.data.relationObject(sourceObject: objectA, relationName: .children, at: 0))
            XCTAssertEqual(objectA.relationIds[.friend]?.count, 1)
            XCTAssertNil(
                database.data.relationObject(sourceObject: objectA, relationName: .friend, at: 0))
        }

        do {
            let objects = try await database.executor.fetchSyncedObjects(
                .init(stableIds: [.objectA: [objectA]].relationStableIds))

            XCTAssertEqual(objects.count, 2)

            let bObjects = try XCTUnwrap(objects[.objectB])
            let objectB = try XCTUnwrap(bObjects.objects[.stable(.init(1))])

            XCTAssertEqual(bObjects.objects.count, 1)
            XCTAssertEqual(
                database.data.relationObject(sourceObject: objectA, relationName: .children, at: 0)?
                    .id,
                objectB.id)
            XCTAssertEqual(
                database.data.relationObject(sourceObject: objectB, relationName: .parent, at: 0)?
                    .id,
                objectA.id)

            let cObjects = try XCTUnwrap(objects[.objectC])
            let objectC = try XCTUnwrap(cObjects.objects[.stable(.init(1))])

            XCTAssertEqual(cObjects.objects.count, 1)
            XCTAssertEqual(
                database.data.relationObject(sourceObject: objectA, relationName: .friend, at: 0)?
                    .id,
                objectC.id)
            XCTAssertEqual(
                database.data.relationObject(sourceObject: objectC, relationName: .friend, at: 0)?
                    .id,
                objectA.id)
        }
    }

    @MainActor
    func testFetchReadOnlyObjects() async throws {
        let model = TestUtils.makeModel0_0_1()
        let (database, _) = try await TestUtils.makeDatabaseWithSetup(uuid: uuid, model: model)

        let insertedObjects = try await database.executor.insertSyncedObjects(counts: [
            .objectA: 1, .objectB: 1,
        ])

        XCTAssertEqual(database.data.info.currentSaveId, 1)
        XCTAssertEqual(database.data.info.lastSaveId, 1)

        let insertedAObject = try XCTUnwrap(insertedObjects[.objectA]?.objects.first?.value)
        let insertedBObject = try XCTUnwrap(insertedObjects[.objectB]?.objects.first?.value)
        insertedAObject.setAttributeValue(.text("value_0"), forName: .name)
        insertedAObject.addRelationId(insertedBObject.id, forName: .children)

        XCTAssertEqual(insertedBObject.id.stable?.rawValue, 1)

        let _ = try await database.executor.save()

        let fetchedObjects = try await database.executor.fetchReadOnlyObjects(
            .init(selects: [.init(table: .objectA)]))

        let fetchedAObjects = try XCTUnwrap(fetchedObjects[.objectA])
        XCTAssertEqual(fetchedAObjects.order.count, 1)
        XCTAssertEqual(fetchedAObjects.objects.count, 1)
        let fetchedAObject = try XCTUnwrap(fetchedAObjects.object(at: 0))
        XCTAssertEqual(fetchedAObject.loadingId.stable.rawValue, 1)
        XCTAssertEqual(fetchedAObject.attributeValue(forName: .name), .text("value_0"))

        XCTAssertEqual(fetchedAObject.relationIds(forName: .children).count, 1)
        XCTAssertEqual(fetchedAObject.relationIds(forName: .children)[0].stable?.rawValue, 1)
    }

    @MainActor
    func testFetchReadOnlyObjectsByIds() async throws {
        let model = TestUtils.makeModel0_0_1()
        let (database, _) = try await TestUtils.makeDatabaseWithSetup(uuid: uuid, model: model)

        let insertedObjects = try await database.executor.insertSyncedObjects(counts: [
            .objectA: 3
        ])

        XCTAssertEqual(database.data.info.currentSaveId, 1)
        XCTAssertEqual(database.data.info.lastSaveId, 1)

        let insertedAObjects = try XCTUnwrap(insertedObjects[.objectA]?.array)
        insertedAObjects[0].setAttributeValue(.text("value_1"), forName: .name)
        insertedAObjects[1].setAttributeValue(.text("value_2"), forName: .name)
        insertedAObjects[2].setAttributeValue(.text("value_3"), forName: .name)

        let insertedAId1 = insertedAObjects[0].id
        let insertedAId2 = insertedAObjects[1].id
        let insertedAId3 = insertedAObjects[2].id

        XCTAssertEqual(insertedAId1.stable?.rawValue, 1)
        XCTAssertEqual(insertedAId2.stable?.rawValue, 2)
        XCTAssertEqual(insertedAId3.stable?.rawValue, 3)

        let _ = try await database.executor.save()

        let fetchedObjects = try await database.executor.fetchReadOnlyObjects(
            .init(stableIds: [.objectA: [.init(2), .init(3), .init(4)]]))
        let fetchedAObjects = try XCTUnwrap(fetchedObjects[.objectA])

        // 存在していない4は単に含まれない
        // 直にInsertした場合のIdはStableのみ
        XCTAssertEqual(fetchedAObjects.order.count, 2)
        XCTAssertEqual(fetchedAObjects.objects.count, 2)
        XCTAssertEqual(fetchedAObjects.objects[.stable(.init(2))]?.loadingId.stable.rawValue, 2)
        XCTAssertEqual(
            fetchedAObjects.objects[.stable(.init(2))]?.attributeValue(forName: .name),
            .text("value_2"))
        XCTAssertEqual(fetchedAObjects.objects[.stable(.init(3))]?.loadingId.stable.rawValue, 3)
        XCTAssertEqual(
            fetchedAObjects.objects[.stable(.init(3))]?.attributeValue(forName: .name),
            .text("value_3"))
    }

    @MainActor
    func testFetchMutableRelationObjects() async throws {
        let model = TestUtils.makeModel0_0_2()
        let (database, _) = try await TestUtils.makeDatabaseWithSetup(uuid: uuid, model: model)

        let objectA1 = database.data.createObject(entityName: .objectA)
        let objectA2 = database.data.createObject(entityName: .objectA)
        let objectB1 = database.data.createObject(entityName: .objectB)
        let objectB2 = database.data.createObject(entityName: .objectB)
        let objectB3 = database.data.createObject(entityName: .objectB)
        let objectB4 = database.data.createObject(entityName: .objectB)
        let objectC1 = database.data.createObject(entityName: .objectC)

        objectA1.addRelationObject(objectB1, forName: .children)
        objectA1.addRelationObject(objectB2, forName: .children)
        objectA1.addRelationObject(objectB3, forName: .children)
        objectA2.addRelationObject(objectB3, forName: .children)
        objectA2.addRelationObject(objectB4, forName: .children)
        objectA1.addRelationObject(objectC1, forName: .friend)

        let _ = try await database.executor.save()

        let fetchedObjects = try await database.executor.fetchSyncedObjects(
            .init(stableIds: [objectA1, objectA2].relationStableIds))

        XCTAssertEqual(fetchedObjects.count, 2)

        let fetchedBObjects = try XCTUnwrap(fetchedObjects[.objectB])
        XCTAssertEqual(fetchedBObjects.objects.count, 4)
        XCTAssertNotNil(fetchedBObjects.objects[objectB1.id])
        XCTAssertNotNil(fetchedBObjects.objects[objectB2.id])
        XCTAssertNotNil(fetchedBObjects.objects[objectB3.id])
        XCTAssertNotNil(fetchedBObjects.objects[objectB4.id])

        let fetchedCObjects = try XCTUnwrap(fetchedObjects[.objectC])
        XCTAssertEqual(fetchedCObjects.objects.count, 1)
        XCTAssertNotNil(fetchedCObjects.objects[objectC1.id])
    }

    @MainActor
    func testFetchReadOnlyRelationObjects() async throws {
        let model = TestUtils.makeModel0_0_2()
        let (database, _) = try await TestUtils.makeDatabaseWithSetup(uuid: uuid, model: model)

        let objectA1 = database.data.createObject(entityName: .objectA)
        let objectA2 = database.data.createObject(entityName: .objectA)
        let objectB1 = database.data.createObject(entityName: .objectB)
        let objectB2 = database.data.createObject(entityName: .objectB)
        let objectB3 = database.data.createObject(entityName: .objectB)
        let objectB4 = database.data.createObject(entityName: .objectB)
        let objectC1 = database.data.createObject(entityName: .objectC)

        objectA1.addRelationObject(objectB1, forName: .children)
        objectA1.addRelationObject(objectB2, forName: .children)
        objectA1.addRelationObject(objectB3, forName: .children)
        objectA2.addRelationObject(objectB3, forName: .children)
        objectA2.addRelationObject(objectB4, forName: .children)
        objectA1.addRelationObject(objectC1, forName: .friend)

        let _ = try await database.executor.save()

        let fetchedObjects = try await database.executor.fetchReadOnlyObjects(
            .init(stableIds: [objectA1, objectA2].relationStableIds))

        XCTAssertEqual(fetchedObjects.count, 2)

        let fetchedBObjects = try XCTUnwrap(fetchedObjects[.objectB])
        XCTAssertEqual(fetchedBObjects.objects.count, 4)
        XCTAssertNotNil(fetchedBObjects.objects[objectB1.id])
        XCTAssertNotNil(fetchedBObjects.objects[objectB2.id])
        XCTAssertNotNil(fetchedBObjects.objects[objectB3.id])
        XCTAssertNotNil(fetchedBObjects.objects[objectB4.id])

        let fetchedCObjects = try XCTUnwrap(fetchedObjects[.objectC])
        XCTAssertEqual(fetchedCObjects.objects.count, 1)
        XCTAssertNotNil(fetchedCObjects.objects[objectC1.id])
    }

    @MainActor
    func testSaveObjects() async throws {
        let model = TestUtils.makeModel0_0_1()
        let (database, executor) = try await TestUtils.makeDatabaseWithSetup(
            uuid: uuid, model: model)

        XCTAssertEqual(database.data.info.currentSaveId, 0)
        XCTAssertEqual(database.data.info.lastSaveId, 0)

        let insertedObjects = try await database.executor.insertSyncedObjects(counts: [
            .objectA: 1
        ])
        let insertedAObjects = try XCTUnwrap(insertedObjects[.objectA]?.objects)

        var mainObjects: [StableId: SyncedObject] = [:]

        for (_, object) in insertedAObjects {
            let stableId = try XCTUnwrap(object.id.stable)
            mainObjects[stableId] = object

            XCTAssertEqual(object.attributeValue(forName: .name), .text("default_value"))
            XCTAssertEqual(object.status, .saved)
            XCTAssertEqual(object.action, .insert)
        }

        XCTAssertEqual(mainObjects.count, 1)

        XCTAssertEqual(database.data.info.currentSaveId, 1)
        XCTAssertEqual(database.data.info.lastSaveId, 1)

        do {
            let savedObjects = try await database.executor.save()

            XCTAssertEqual(savedObjects.count, 0)
        }

        XCTAssertEqual(mainObjects.count, 1)

        let object = try XCTUnwrap(mainObjects[.init(1)])
        object.setAttributeValue(.text("new_value"), forName: .name)
        object.setAttributeValue(.integer(77), forName: .age)
        object.addRelationId(.stable(.init(100)), forName: .children)
        object.addRelationId(.stable(.init(200)), forName: .children)

        XCTAssertEqual(object.status, .changed)

        do {
            let savedObjects = try await database.executor.save()

            XCTAssertEqual(savedObjects.count, 1)

            let savedAObjects = try XCTUnwrap(savedObjects[.objectA])

            XCTAssertEqual(savedAObjects.objects.count, 1)

            let object = try XCTUnwrap(savedAObjects.objects.first?.value)

            XCTAssertEqual(object.attributeValue(forName: .name), .text("new_value"))
            XCTAssertEqual(object.attributeValue(forName: .age), .integer(77))
            XCTAssertEqual(object.status, .saved)
            XCTAssertEqual(object.action, .update)
            XCTAssertEqual(object.relationIds.count, 1)
            XCTAssertEqual(object.relationIds(forName: .children).count, 2)
            XCTAssertEqual(object.relationIds(forName: .children)[0].stable?.rawValue, 100)
            XCTAssertEqual(object.relationIds(forName: .children)[1].stable?.rawValue, 200)
        }

        do {
            guard await executor.open() else {
                XCTFail()
                return
            }

            let selectedValues = try await executor.select(
                .init(table: .objectA)
            )

            await executor.close()

            XCTAssertEqual(selectedValues.count, 2)
            XCTAssertEqual(selectedValues[0][.name], .text("default_value"))
            XCTAssertEqual(selectedValues[0][.age], .integer(10))
            XCTAssertEqual(selectedValues[0][.saveId], .integer(1))
            XCTAssertEqual(selectedValues[0][.action], .insertAction)
            XCTAssertEqual(selectedValues[1][.name], .text("new_value"))
            XCTAssertEqual(selectedValues[1][.age], .integer(77))
            XCTAssertEqual(selectedValues[1][.saveId], .integer(2))
            XCTAssertEqual(selectedValues[1][.action], .updateAction)
        }

        do {
            guard await executor.open() else {
                XCTFail()
                return
            }

            let relationTable = try XCTUnwrap(model.entities[.objectA]?.relations[.children]?.table)
            let selectedValues = try await executor.select(
                .init(table: relationTable)
            )

            await executor.close()

            XCTAssertEqual(selectedValues.count, 2)
            XCTAssertEqual(selectedValues[0][.targetObjectId], .integer(100))
            XCTAssertEqual(selectedValues[1][.targetObjectId], .integer(200))
        }

        XCTAssertEqual(database.data.info.currentSaveId, 2)
        XCTAssertEqual(database.data.info.lastSaveId, 2)
        XCTAssertEqual(object.attributeValue(forName: .name), .text("new_value"))
        XCTAssertEqual(object.attributeValue(forName: .age), .integer(77))
        XCTAssertEqual(object.status, .saved)
        XCTAssertEqual(object.relationIds(forName: .children).count, 2)
        XCTAssertEqual(object.relationIds(forName: .children)[0].stable?.rawValue, 100)
        XCTAssertEqual(object.relationIds(forName: .children)[1].stable?.rawValue, 200)

        object.remove()

        XCTAssertEqual(object.status, .changed)

        do {
            let savedObjects = try await database.executor.save()
            let savedAObjects = try XCTUnwrap(savedObjects[.objectA])

            XCTAssertEqual(savedAObjects.objects.count, 1)

            let object = try XCTUnwrap(savedAObjects.objects.first?.value)
            XCTAssertEqual(object.attributeValue(forName: .name), .null)
            XCTAssertEqual(object.attributeValue(forName: .age), .null)
            XCTAssertEqual(object.relationIds(forName: .children).count, 0)
            XCTAssertEqual(object.status, .saved)
            XCTAssertEqual(object.action, .remove)
        }

        XCTAssertEqual(database.data.info.currentSaveId, 3)
        XCTAssertEqual(database.data.info.lastSaveId, 3)

        do {
            let savedObjects = try await database.executor.save()

            XCTAssertEqual(savedObjects.count, 0)
        }

        XCTAssertEqual(database.data.info.currentSaveId, 3)
        XCTAssertEqual(database.data.info.lastSaveId, 3)
    }

    @MainActor
    func testChangeAndSaveAfterUndo() async throws {
        let model = TestUtils.makeModel0_0_1()
        let (database, executor) = try await TestUtils.makeDatabaseWithSetup(
            uuid: uuid, model: model)

        XCTAssertEqual(database.data.info.currentSaveId, 0)
        XCTAssertEqual(database.data.info.lastSaveId, 0)

        let insertedObjects = try await database.executor.insertSyncedObjects(counts: [.objectA: 2]
        )

        XCTAssertEqual(database.data.info.currentSaveId, 1)

        let aObjects = try XCTUnwrap(insertedObjects[.objectA]?.array)
        XCTAssertEqual(aObjects.count, 2)

        // オブジェクトの値を変更して保存を2回行う

        aObjects[0].setAttributeValue(.text("name_value_0"), forName: .name)

        let _ = try await database.executor.save()

        XCTAssertEqual(database.data.info.currentSaveId, 2)

        aObjects[1].setAttributeValue(.text("name_value_1_a"), forName: .name)

        let _ = try await database.executor.save()

        XCTAssertEqual(database.data.info.currentSaveId, 3)

        // 一つ前にundoする

        let _ = try await database.executor.revert(saveId: 2)

        XCTAssertEqual(database.data.info.currentSaveId, 2)

        // オブジェクトの値を変更して保存する

        aObjects[1].setAttributeValue(.text("name_value_1_b"), forName: .name)

        let _ = try await database.executor.save()

        XCTAssertEqual(database.data.info.currentSaveId, 3)

        do {
            guard await executor.open() else {
                XCTFail()
                return
            }

            let selectedValues = try await executor.select(
                .init(table: .objectA)
            )

            XCTAssertEqual(selectedValues.count, 4)

            // undo前の値は残っていない
            for values in selectedValues {
                XCTAssertNotEqual(values[.name], .text("name_value_1_a"))
            }

            await executor.close()
        }
    }

    @MainActor
    func testInsertAndSaveAfterUndoWithStableIds() async throws {
        let model = TestUtils.makeModel0_0_1()
        let (database, _) = try await TestUtils.makeDatabaseWithSetup(
            uuid: uuid, model: model)

        XCTAssertEqual(database.data.info.currentSaveId, 0)

        // オブジェクトの追加を2回行う

        let insertedObjects1 = try await database.executor.insertSyncedObjects(counts: [
            .objectA: 1
        ])
        let object1 = try XCTUnwrap(insertedObjects1[.objectA]?.objects.first?.value)
        let objectId1 = object1.id

        XCTAssertEqual(database.data.info.currentSaveId, 1)
        XCTAssertEqual(objectId1.stable, .init(1))

        let insertedObjects2 = try await database.executor.insertSyncedObjects(counts: [
            .objectA: 1
        ])
        let object2 = try XCTUnwrap(insertedObjects2[.objectA]?.objects.first?.value)
        let objectId2 = object2.id

        XCTAssertEqual(database.data.info.currentSaveId, 2)
        XCTAssertEqual(objectId2.stable, .init(2))

        // 一つ前にundoする

        _ = try await database.executor.revert(saveId: 1)

        XCTAssertEqual(database.data.info.currentSaveId, 1)
        XCTAssertTrue(object1.isAvailable)
        XCTAssertFalse(object2.isAvailable)

        // オブジェクトを追加する

        let insertedObjects2b = try await database.executor.insertSyncedObjects(counts: [
            .objectA: 1
        ])
        let object2b = try XCTUnwrap(insertedObjects2b[.objectA]?.objects.first?.value)
        let objectId2b = object2b.id

        XCTAssertEqual(database.data.info.currentSaveId, 2)
        XCTAssertEqual(objectId2b.stable, .init(2))
        XCTAssertFalse(object2.isAvailable)
        XCTAssertTrue(object2b.isAvailable)
        XCTAssertNotEqual(ObjectIdentifier(object2), ObjectIdentifier(object2b))
        XCTAssertEqual(objectId2.stable, objectId2b.stable)
    }

    @MainActor
    func testInsertAndSaveAfterUndoWithBothIds() async throws {
        let model = TestUtils.makeModel0_0_1()
        let (database, _) = try await TestUtils.makeDatabaseWithSetup(
            uuid: uuid, model: model)

        XCTAssertEqual(database.data.info.currentSaveId, 0)

        // オブジェクトの生成を2回行う

        let object1 = database.data.createObject(entityName: .objectA)

        _ = try await database.executor.save()

        XCTAssertEqual(database.data.info.currentSaveId, 1)
        XCTAssertEqual(object1.id.stable, .init(1))
        XCTAssertNotNil(object1.id.temporary)

        let object2 = database.data.createObject(entityName: .objectA)

        _ = try await database.executor.save()

        XCTAssertEqual(database.data.info.currentSaveId, 2)
        XCTAssertEqual(object2.id.stable, .init(2))
        XCTAssertNotNil(object2.id.temporary)

        // 一つ前にundoする

        _ = try await database.executor.revert(saveId: 1)

        XCTAssertEqual(database.data.info.currentSaveId, 1)
        XCTAssertTrue(object1.isAvailable)
        XCTAssertFalse(object2.isAvailable)

        // オブジェクトを追加する

        let object2b = database.data.createObject(entityName: .objectA)

        _ = try await database.executor.save()

        XCTAssertEqual(database.data.info.currentSaveId, 2)
        XCTAssertEqual(object2b.id.stable, .init(2))
        XCTAssertNotNil(object2b.id.temporary)
        XCTAssertFalse(object2.isAvailable)
        XCTAssertTrue(object2b.isAvailable)
        // オブジェクトの新規追加時にpool内のidは上書きされるので、undo前のオブジェクトは流用されない
        XCTAssertNotEqual(ObjectIdentifier(object2), ObjectIdentifier(object2b))
        XCTAssertNotEqual(object2.id.temporary, object2b.id.temporary)
    }

    @MainActor
    func testSaveRemovedAfterCreation() async throws {
        let model = TestUtils.makeModel0_0_1()
        let (database, _) = try await TestUtils.makeDatabaseWithSetup(
            uuid: uuid, model: model)

        let object = database.data.createObject(entityName: .objectA)

        XCTAssertTrue(object.isAvailable)

        object.remove()

        XCTAssertFalse(object.isAvailable)

        let _ = try await database.executor.save()

        XCTAssertFalse(object.isAvailable)

        let fetched = try await database.executor.fetchReadOnlyObjects(
            .init(selects: [.init(table: .objectA)]))

        XCTAssertEqual(fetched[.objectA]?.objects.count, 0)
    }

    @MainActor
    func testRevertObjects() async throws {
        let model = TestUtils.makeModel0_0_1()
        let (database, executor) = try await TestUtils.makeDatabaseWithSetup(
            uuid: uuid, model: model)

        XCTAssertEqual(database.data.info.currentSaveId, 0)
        XCTAssertEqual(database.data.info.lastSaveId, 0)

        let insertedObjects = try await database.executor.insertSyncedObjects(counts: [.objectA: 1]
        )
        let insertedAObject = try XCTUnwrap(insertedObjects[.objectA]?.objects.first?.value)

        insertedAObject.setAttributeValue(.text("value_2"), forName: .name)

        _ = try await database.executor.save()

        insertedAObject.remove()

        _ = try await database.executor.save()

        XCTAssertEqual(insertedAObject.action, .remove)
        XCTAssertFalse(insertedAObject.isAvailable)

        let revertedResult = try await database.executor.revert(saveId: 2)

        let revertedAObject = try XCTUnwrap(revertedResult[.objectA]?.objects.first?.value)

        XCTAssertEqual(insertedAObject.action, .remove)
        XCTAssertFalse(insertedAObject.isAvailable)
        XCTAssertEqual(revertedAObject.attributeValue(forName: .name), .text("value_2"))
        XCTAssertNotEqual(revertedAObject.action, .remove)

        _ = try await database.executor.revert(saveId: 1)

        XCTAssertEqual(revertedAObject.attributeValue(forName: .name), .text("default_value"))

        revertedAObject.setAttributeValue(.text("value_b"), forName: .name)

        _ = try await database.executor.save()

        do {
            guard await executor.open() else {
                XCTFail()
                return
            }

            do {
                let selectedValues = try await executor.select(
                    .init(table: .objectA, columnOrders: [.init(name: .saveId, order: .ascending)])
                )

                XCTAssertEqual(selectedValues.count, 2)
                XCTAssertEqual(selectedValues[0][.saveId], .integer(1))
                XCTAssertEqual(selectedValues[0][.name], .text("default_value"))
                XCTAssertEqual(selectedValues[1][.saveId], .integer(2))
                XCTAssertEqual(selectedValues[1][.name], .text("value_b"))
            }

            await executor.close()
        }

        _ = try await database.executor.revert(saveId: 0)

        XCTAssertEqual(revertedAObject.status, .cleared)
        XCTAssertNil(revertedAObject.action)
        XCTAssertEqual(revertedAObject.attributeValue(forName: .name), .null)
    }

    @MainActor
    func testRestoreRevertedDatabase() async throws {
        let model = TestUtils.makeModel0_0_1()

        do {
            let (database, _) = try await TestUtils.makeDatabaseWithSetup(uuid: uuid, model: model)

            XCTAssertEqual(database.data.info.currentSaveId, 0)
            XCTAssertEqual(database.data.info.lastSaveId, 0)

            let insertedData = try await database.executor.insertSyncedObjects(counts: [
                .objectA: 1, .objectB: 2,
            ])
            let objectA = try XCTUnwrap(insertedData[.objectA]?.objects.first?.value)
            let objectB0 = try XCTUnwrap(insertedData[.objectB]?.array[0])
            let objectB1 = try XCTUnwrap(insertedData[.objectB]?.array[1])

            XCTAssertEqual(database.data.info.currentSaveId, 1)
            XCTAssertEqual(database.data.info.lastSaveId, 1)

            objectA.setAttributeValue(.text("name_value_1"), forName: .name)
            objectB0.setAttributeValue(.text("name_value_2"), forName: .fullname)
            objectB1.setAttributeValue(.text("name_value_3"), forName: .fullname)

            let _ = try await database.executor.save()

            XCTAssertEqual(database.data.info.currentSaveId, 2)
            XCTAssertEqual(database.data.info.lastSaveId, 2)

            objectA.setAttributeValue(.text("name_value_4"), forName: .name)
            objectB0.setAttributeValue(.text("name_value_5"), forName: .fullname)
            objectA.setRelationObjects([objectB0], forName: .children)
            XCTAssertEqual(objectB0.id.stable?.rawValue, 1)

            let _ = try await database.executor.save()

            XCTAssertEqual(database.data.info.currentSaveId, 3)
            XCTAssertEqual(database.data.info.lastSaveId, 3)

            objectA.setAttributeValue(.text("name_value_6"), forName: .name)
            objectB0.setAttributeValue(.text("name_value_7"), forName: .fullname)
            objectA.setRelationObjects([objectB1], forName: .children)

            let _ = try await database.executor.save()

            XCTAssertEqual(database.data.info.currentSaveId, 4)
            XCTAssertEqual(database.data.info.lastSaveId, 4)

            let _ = try await database.executor.revert(saveId: 3)

            XCTAssertEqual(database.data.info.currentSaveId, 3)
            XCTAssertEqual(database.data.info.lastSaveId, 4)
        }

        do {
            let (database, _) = try await TestUtils.makeDatabaseWithSetup(uuid: uuid, model: model)

            XCTAssertEqual(database.data.info.currentSaveId, 3)
            XCTAssertEqual(database.data.info.lastSaveId, 4)

            do {
                let objects = try await database.executor.fetchSyncedObjects(
                    .init(selects: [.init(table: .objectA)]))
                let aObjects = try XCTUnwrap(objects[.objectA])
                let aObject0 = try XCTUnwrap(aObjects.object(at: 0))

                XCTAssertEqual(aObject0.attributeValue(forName: .name), .text("name_value_4"))
                XCTAssertEqual(aObject0.relationIds[.children]?.count, 1)

                let relationObjects = try await database.executor.fetchSyncedObjects(
                    .init(stableIds: objects.relationStableIds))
                let relationBObjects = try XCTUnwrap(relationObjects[.objectB])

                XCTAssertEqual(relationBObjects.objects.count, 1)
                XCTAssertEqual(
                    relationBObjects.objects[.stable(.init(1))]?.attributeValue(forName: .fullname),
                    .text("name_value_5"))

                XCTAssertEqual(
                    database.data.relationObject(
                        sourceObject: aObject0, relationName: .children, at: 0)?
                        .attributeValue(forName: .fullname), .text("name_value_5"))
            }
        }
    }

    @MainActor
    func testClear() async throws {
        let model = TestUtils.makeModel0_0_1()
        let (database, _) = try await TestUtils.makeDatabaseWithSetup(uuid: uuid, model: model)

        let insertedObjects = try await database.executor.insertSyncedObjects(values: [
            .objectA: [[:]]
        ])
        let object = try XCTUnwrap(insertedObjects[.objectA]?.objects.first?.value)
        object.setAttributeValue(.text("test_clear_value"), forName: .name)

        let _ = try await database.executor.save()

        XCTAssertEqual(object.status, .saved)
        XCTAssertEqual(object.id.stable?.rawValue, 1)
        XCTAssertEqual(object.attributeValue(forName: .name), .text("test_clear_value"))

        XCTAssertNotNil(
            database.data.cachedOrCreatedObject(
                entityName: .objectA, objectId: .stable(.init(1))))

        try await database.executor.clear()

        XCTAssertEqual(object.status, .cleared)
        XCTAssertEqual(object.attributeValue(forName: .name), .null)

        XCTAssertNil(
            database.data.cachedOrCreatedObject(
                entityName: .objectA, objectId: .stable(.init(1))))
    }

    @MainActor
    func testClearWhenChangedObjectsExist() async throws {
        let model = TestUtils.makeModel0_0_1()
        let (database, _) = try await TestUtils.makeDatabaseWithSetup(uuid: uuid, model: model)

        guard
            let object = try await database.executor.insertSyncedObjects(counts: [.objectA: 1])[
                .objectA]?.objects.first?.value
        else {
            XCTFail()
            return
        }

        object.setAttributeValue(.text("changed-text"), forName: .name)

        XCTAssertTrue(database.data.hasChangedObjects)
        XCTAssertFalse(database.data.hasCreatedObjects)
        XCTAssertTrue(object.isAvailable)

        _ = try await database.executor.clear()

        XCTAssertFalse(database.data.hasChangedObjects)
        XCTAssertFalse(object.isAvailable)
    }

    @MainActor
    func testClearWhenCreatedObjectsExist() async throws {
        let model = TestUtils.makeModel0_0_1()
        let (database, _) = try await TestUtils.makeDatabaseWithSetup(uuid: uuid, model: model)

        let object = database.data.createObject(entityName: .objectA)

        XCTAssertTrue(database.data.hasCreatedObjects)
        XCTAssertFalse(database.data.hasChangedObjects)
        XCTAssertTrue(object.isAvailable)

        _ = try await database.executor.clear()

        XCTAssertFalse(database.data.hasCreatedObjects)
        XCTAssertFalse(object.isAvailable)
    }

    @MainActor
    func testPurge() async throws {
        let model = TestUtils.makeModel0_0_1()
        let (database, executor) = try await TestUtils.makeDatabaseWithSetup(
            uuid: uuid, model: model)

        let insertedData = try await database.executor.insertSyncedObjects(counts: [
            .objectA: 1, .objectB: 2,
        ])
        let objectA = try XCTUnwrap(insertedData[.objectA]?.objects.first?.value)
        let bObjects = try XCTUnwrap(insertedData[.objectB]?.array)
        let objectB0 = bObjects[0]
        let objectB1 = bObjects[1]

        objectA.setAttributeValue(.text("obj_a_2"), forName: .name)
        objectB0.setAttributeValue(.text("obj_b0_2"), forName: .fullname)
        objectB1.setAttributeValue(.text("obj_b1_2"), forName: .fullname)

        objectA.setRelationObjects([objectB0], forName: .children)

        let _ = try await database.executor.save()

        XCTAssertEqual(database.data.info.currentSaveId, 2)

        objectA.setAttributeValue(.text("obj_a_3"), forName: .name)
        objectB0.setAttributeValue(.text("obj_b0_3"), forName: .fullname)
        objectB1.setAttributeValue(.text("obj_b1_3"), forName: .fullname)

        objectA.setRelationObjects([objectB0, objectB1], forName: .children)

        let _ = try await database.executor.save()

        XCTAssertEqual(database.data.info.currentSaveId, 3)

        objectA.setAttributeValue(.text("obj_a_4"), forName: .name)
        objectB0.setAttributeValue(.text("obj_b0_4"), forName: .fullname)
        objectB1.setAttributeValue(.text("obj_b1_4"), forName: .fullname)

        objectA.setRelationObjects([objectB1], forName: .children)

        let _ = try await database.executor.save()

        XCTAssertEqual(database.data.info.currentSaveId, 4)

        let _ = try await database.executor.revert(saveId: 3)

        XCTAssertEqual(database.data.info.currentSaveId, 3)
        XCTAssertEqual(database.data.info.lastSaveId, 4)

        try await database.executor.purge()

        XCTAssertEqual(database.data.info.currentSaveId, 1)
        XCTAssertEqual(database.data.info.lastSaveId, 1)

        objectA.setAttributeValue(.text("obj_a_3"), forName: .name)
        objectB0.setAttributeValue(.text("obj_b0_3"), forName: .fullname)
        objectB1.setAttributeValue(.text("obj_b1_3"), forName: .fullname)

        do {
            guard await executor.open() else {
                XCTFail()
                return
            }

            let relationTable = try XCTUnwrap(model.entities[.objectA]?.relations[.children]?.table)

            let aObjects = try await executor.select(.init(table: .objectA))
            let objectA = aObjects[0]

            XCTAssertEqual(aObjects.count, 1)
            XCTAssertEqual(objectA[.name], .text("obj_a_3"))
            XCTAssertEqual(objectA[.saveId], .integer(1))

            let bObjects = try await executor.select(.init(table: .objectB))

            XCTAssertEqual(bObjects.count, 2)

            let bObjectsDict: [Int64: [SQLColumn.Name: SQLValue]] = bObjects.reduce(into: .init()) {
                partialResult, object in
                if let objectId = object[.objectId]?.integerValue {
                    partialResult[.init(objectId)] = object
                }
            }

            XCTAssertEqual(bObjectsDict[1]?[.fullname], .text("obj_b0_3"))
            XCTAssertEqual(bObjectsDict[1]?[.saveId], .integer(1))
            XCTAssertEqual(bObjectsDict[2]?[.fullname], .text("obj_b1_3"))
            XCTAssertEqual(bObjectsDict[2]?[.saveId], .integer(1))

            let relationObjects = try await executor.select(
                .init(table: relationTable)
            )

            XCTAssertEqual(relationObjects.count, 2)

            XCTAssertEqual(relationObjects[0][.sourcePkId], .integer(3))
            XCTAssertEqual(relationObjects[0][.sourceObjectId], .integer(1))
            XCTAssertEqual(relationObjects[0][.targetObjectId], .integer(1))
            XCTAssertEqual(relationObjects[0][.saveId], .integer(1))
            XCTAssertEqual(relationObjects[1][.sourcePkId], .integer(3))
            XCTAssertEqual(relationObjects[1][.sourceObjectId], .integer(1))
            XCTAssertEqual(relationObjects[1][.targetObjectId], .integer(2))
            XCTAssertEqual(relationObjects[1][.saveId], .integer(1))

            await executor.close()
        }
    }

    @MainActor
    func testHasInserted() async throws {
        let model = TestUtils.makeModel0_0_1()
        let (database, _) = try await TestUtils.makeDatabaseWithSetup(uuid: uuid, model: model)

        XCTAssertFalse(database.data.hasCreatedObjects)

        let _ = database.data.createObject(entityName: .objectA)

        XCTAssertTrue(database.data.hasCreatedObjects)

        let _ = try await database.executor.save()

        XCTAssertFalse(database.data.hasCreatedObjects)
    }

    @MainActor
    func testHasChanged() async throws {
        let model = TestUtils.makeModel0_0_1()
        let (database, _) = try await TestUtils.makeDatabaseWithSetup(uuid: uuid, model: model)

        let insertedData = try await database.executor.insertSyncedObjects(counts: [.objectA: 1])

        XCTAssertFalse(database.data.hasChangedObjects)

        let object = try XCTUnwrap(insertedData[.objectA]?.objects.first?.value)
        object.setAttributeValue(.text("a"), forName: .name)

        XCTAssertTrue(database.data.hasChangedObjects)

        let _ = try await database.executor.save()

        XCTAssertFalse(database.data.hasChangedObjects)
    }

    @MainActor
    func testCreatedObjectCount() async throws {
        let model = TestUtils.makeModel0_0_1()
        let (database, _) = try await TestUtils.makeDatabaseWithSetup(uuid: uuid, model: model)

        XCTAssertEqual(database.data.createdObjectCount(entityName: .objectA), 0)

        let _ = database.data.createObject(entityName: .objectA)

        XCTAssertEqual(database.data.createdObjectCount(entityName: .objectA), 1)

        let _ = database.data.createObject(entityName: .objectA)

        XCTAssertEqual(database.data.createdObjectCount(entityName: .objectA), 2)

        let _ = try await database.executor.save()

        XCTAssertEqual(database.data.createdObjectCount(entityName: .objectA), 0)
    }

    @MainActor
    func testChangedObjectCount() async throws {
        let model = TestUtils.makeModel0_0_1()
        let (database, _) = try await TestUtils.makeDatabaseWithSetup(uuid: uuid, model: model)

        let insertedData = try await database.executor.insertSyncedObjects(counts: [.objectA: 2])

        XCTAssertEqual(database.data.changedObjectCount(entityName: .objectA), 0)

        let aObjects = try XCTUnwrap(insertedData[.objectA]?.array)
        let objectA0 = aObjects[0]
        let objectA1 = aObjects[1]

        objectA0.setAttributeValue(.text("a"), forName: .name)

        XCTAssertEqual(database.data.changedObjectCount(entityName: .objectA), 1)

        objectA1.setAttributeValue(.text("b"), forName: .name)

        XCTAssertEqual(database.data.changedObjectCount(entityName: .objectA), 2)

        let _ = try await database.executor.save()

        XCTAssertEqual(database.data.changedObjectCount(entityName: .objectA), 0)
    }

    @MainActor
    func testStableIdIsSetAfterSave() async throws {
        let model = TestUtils.makeModel0_0_1()
        let (database, _) = try await TestUtils.makeDatabaseWithSetup(uuid: uuid, model: model)

        let object = database.data.createObject(entityName: .objectA)

        XCTAssertNil(object.id.stable)

        let _ = try await database.executor.save()

        XCTAssertNotNil(object.id.stable)
    }

    @MainActor
    func testResetWhenChangedObjectsExist() async throws {
        let model = TestUtils.makeModel0_0_1()
        let (database, _) = try await TestUtils.makeDatabaseWithSetup(uuid: uuid, model: model)

        let insertedData = try await database.executor.insertSyncedObjects(counts: [
            .objectA: 1, .objectB: 2,
        ])

        let objectA = try XCTUnwrap(insertedData[.objectA]?.objects.first?.value)
        let bObjects = try XCTUnwrap(insertedData[.objectB]?.array)
        let objectB0 = bObjects[0]
        let objectB1 = bObjects[1]

        objectA.setAttributeValue(.text("a_test_1"), forName: .name)
        objectB0.setAttributeValue(.text("b0_test_1"), forName: .fullname)
        objectB1.setAttributeValue(.text("b1_test_1"), forName: .fullname)
        objectA.setRelationObjects([objectB0], forName: .children)

        let _ = try await database.executor.save()

        objectA.setAttributeValue(.text("a_test_2"), forName: .name)
        objectB0.setAttributeValue(.text("b0_test_2"), forName: .fullname)
        objectB1.setAttributeValue(.text("b1_test_2"), forName: .fullname)
        objectA.setRelationObjects([objectB1, objectB0], forName: .children)

        XCTAssertTrue(database.data.hasChangedObjects)
        XCTAssertFalse(database.data.hasCreatedObjects)
        XCTAssertEqual(objectA.status, .changed)
        XCTAssertEqual(objectB0.status, .changed)
        XCTAssertEqual(objectB1.status, .changed)

        let resetResult = try await database.executor.reset()

        XCTAssertEqual(resetResult.count, 2)
        let resultAObjects = try XCTUnwrap(resetResult[.objectA])
        XCTAssertEqual(resultAObjects.order.count, 1)
        XCTAssertEqual(resultAObjects.order[0], objectA.id)
        XCTAssertEqual(resultAObjects.objects.count, 1)
        XCTAssertEqual(
            ObjectIdentifier(resultAObjects.objects[objectA.id]!), ObjectIdentifier(objectA))
        let resultBObjects = try XCTUnwrap(resetResult[.objectB])
        XCTAssertEqual(resultBObjects.order.count, 2)
        XCTAssertTrue(resultBObjects.order.contains(objectB0.id))
        XCTAssertTrue(resultBObjects.order.contains(objectB1.id))
        XCTAssertEqual(resultBObjects.objects.count, 2)
        XCTAssertEqual(
            ObjectIdentifier(resultBObjects.objects[objectB0.id]!), ObjectIdentifier(objectB0))
        XCTAssertEqual(
            ObjectIdentifier(resultBObjects.objects[objectB1.id]!), ObjectIdentifier(objectB1))

        XCTAssertFalse(database.data.hasChangedObjects)
        XCTAssertEqual(objectA.status, .saved)
        XCTAssertEqual(objectB0.status, .saved)
        XCTAssertEqual(objectB1.status, .saved)

        XCTAssertEqual(objectA.attributeValue(forName: .name), .text("a_test_1"))
        XCTAssertEqual(objectB0.attributeValue(forName: .fullname), .text("b0_test_1"))
        XCTAssertEqual(objectB1.attributeValue(forName: .fullname), .text("b1_test_1"))
        XCTAssertEqual(objectA.relationIds[.children]?.count, 1)
        XCTAssertEqual(
            database.data.relationObject(sourceObject: objectA, relationName: .children, at: 0)?.id,
            objectB0.id)
    }

    @MainActor
    func testResetWhenCreatedObjectsExist() async throws {
        let model = TestUtils.makeModel0_0_1()
        let (database, _) = try await TestUtils.makeDatabaseWithSetup(uuid: uuid, model: model)

        let object = database.data.createObject(entityName: .objectA)

        XCTAssertTrue(database.data.hasCreatedObjects)
        XCTAssertTrue(object.isAvailable)
        XCTAssertEqual(object.status, .created)

        let resetResult = try await database.executor.reset()

        XCTAssertEqual(resetResult.count, 1)
        let resultObjects = try XCTUnwrap(resetResult[.objectA])
        XCTAssertEqual(resultObjects.order.count, 1)
        XCTAssertEqual(resultObjects.order[0], object.id)
        XCTAssertEqual(resultObjects.objects.count, 1)
        XCTAssertEqual(
            ObjectIdentifier(resultObjects.objects[object.id]!), ObjectIdentifier(object))

        XCTAssertFalse(database.data.hasCreatedObjects)
        XCTAssertFalse(object.isAvailable)
        XCTAssertEqual(object.status, .cleared)
    }

    @MainActor
    func testInvertRelationRemovedInCreatedObjects() async throws {
        // 生成直後のオブジェクトを削除して逆関連があった場合に、関連先のオブジェクトから削除されているかテスト

        let model = TestUtils.makeModel0_0_1()
        let (database, _) = try await TestUtils.makeDatabaseWithSetup(uuid: uuid, model: model)

        // objectAとobjectBのオブジェクトを1つずつ生成する
        let objectA = database.data.createObject(entityName: .objectA)
        let objectB0 = database.data.createObject(entityName: .objectB)
        let objectB1 = database.data.createObject(entityName: .objectB)

        // 関連をセット
        objectA.setRelationObjects([objectB0, objectB1], forName: .children)

        XCTContext.runActivity(named: "objectAに関連がセットされていることを確認") { _ in
            XCTAssertEqual(objectA.relationIds(forName: .children).count, 2)

            let relationObjects = database.data.relationObjects(
                sourceObject: objectA, relationName: .children)
            XCTAssertEqual(relationObjects.count, 2)
        }

        // objectBを削除
        objectB0.remove()

        XCTContext.runActivity(named: "objectAから関連が取り除かれている") { _ in
            XCTAssertEqual(objectA.relationIds(forName: .children).count, 1)

            let relationObjects = database.data.relationObjects(
                sourceObject: objectA, relationName: .children)
            XCTAssertEqual(relationObjects.count, 1)
            XCTAssertEqual(relationObjects[0]?.id, objectB1.id)
        }
    }

    @MainActor
    func testInvertRelationRemovedInCachedObjects() async throws {
        // 保存されたオブジェクトを削除して逆関連があった場合に、関連先のオブジェクトから削除されているかテスト

        let model = TestUtils.makeModel0_0_1()
        let (database, _) = try await TestUtils.makeDatabaseWithSetup(uuid: uuid, model: model)

        // objectAとobjectBのオブジェクトを1つずつ挿入する
        var insertedData = try await database.executor.insertSyncedObjects(counts: [
            .objectA: 1, .objectB: 2,
        ])

        let objectA = try XCTUnwrap(insertedData[.objectA]?.objects.first?.value)
        let objectB0 = try XCTUnwrap(insertedData[.objectB]?.array[0])
        let objectB1 = try XCTUnwrap(insertedData[.objectB]?.array[1])

        // 関連をセット
        objectA.setRelationObjects([objectB0, objectB1], forName: .children)

        XCTContext.runActivity(named: "objectAに関連がセットされていることを確認") { _ in
            XCTAssertEqual(objectA.relationIds(forName: .children).count, 2)

            let relationObjects = database.data.relationObjects(
                sourceObject: objectA, relationName: .children)
            XCTAssertEqual(relationObjects.count, 2)
        }

        let _ = try await database.executor.save()

        // objectBを削除
        objectB0.remove()

        XCTContext.runActivity(named: "objectAから関連が取り除かれている") { _ in
            XCTAssertEqual(objectA.relationIds(forName: .children).count, 1)

            let relationObjects = database.data.relationObjects(
                sourceObject: objectA, relationName: .children)
            XCTAssertEqual(relationObjects.count, 1)
            XCTAssertEqual(relationObjects[0]?.id, objectB1.id)
        }

        let _ = try await database.executor.save()

        // キャッシュをクリア
        insertedData.removeAll()

        let fetchedObjects = try await database.executor.fetchSyncedObjects(
            .init(selects: [
                .init(
                    table: .objectA,
                    columnOrders: [.init(name: .objectId, order: .ascending)])
            ]))
        let aObjects = try XCTUnwrap(fetchedObjects[.objectA])

        XCTAssertEqual(aObjects.objects.count, 1)

        XCTContext.runActivity(named: "関連が取り除かれた状態でDBに保存されている") { _ in
            XCTAssertEqual(objectA.relationIds(forName: .children).count, 1)

            let relationObjects = database.data.relationObjects(
                sourceObject: objectA, relationName: .children)
            XCTAssertEqual(relationObjects.count, 1)
        }
    }

    @MainActor
    func testInvertRelationRemovedInDb() async throws {
        // フェッチされていないオブジェクトに逆関連があった場合に、DB上で関連を削除されているかテスト

        let model = TestUtils.makeModel0_0_1()
        let (database, _) = try await TestUtils.makeDatabaseWithSetup(uuid: uuid, model: model)

        let objectA0Id: ObjectId
        let objectA1Id: ObjectId
        let objectA2Id: ObjectId
        let objectB0Id: ObjectId
        let objectB1Id: ObjectId
        let objectB2Id: ObjectId

        var insertedData: SyncedResultData

        do {
            // object_aとobject_bのオブジェクトを3つずつ挿入する
            insertedData = try await database.executor.insertSyncedObjects(counts: [
                .objectA: 3, .objectB: 3,
            ])

            XCTAssertEqual(database.data.info.currentSaveId, 1)

            let aObjects = try XCTUnwrap(insertedData[.objectA]?.array)
            let objectA0 = aObjects[0]
            let objectA1 = aObjects[1]
            let objectA2 = aObjects[2]
            let bObjects = try XCTUnwrap(insertedData[.objectB]?.array)
            let objectB0 = bObjects[0]
            let objectB1 = bObjects[1]
            let objectB2 = bObjects[2]

            objectA0Id = objectA0.id
            objectA1Id = objectA1.id
            objectA2Id = objectA2.id
            objectB0Id = objectB0.id
            objectB1Id = objectB1.id
            objectB2Id = objectB2.id

            // 関連のセット
            objectA0.setRelationObjects([objectB0], forName: .children)
            objectA1.setRelationObjects([objectB2], forName: .children)
            objectA2.setRelationObjects([objectB2], forName: .children)

            let _ = try await database.executor.save()

            XCTAssertEqual(database.data.info.currentSaveId, 2)

            // objectA0の関連にobjectB1、obj_b0をセットする
            objectA0.setRelationObjects([objectB1, objectB0], forName: .children)

            let _ = try await database.executor.save()

            XCTAssertEqual(database.data.info.currentSaveId, 3)

            // objectA1を変更
            objectA1.setAttributeValue(.text("test_name_x"), forName: .name)

            // obj_a2を削除
            objectA2.remove()

            let _ = try await database.executor.save()

            XCTAssertEqual(database.data.info.currentSaveId, 4)

            // object_aのオブジェクトをキャッシュから削除してデータベースに影響ないようにする
            XCTAssertEqual(objectA2.action, .remove)

            insertedData[.objectA] = nil
        }

        // キャッシュが残っていないことを確認
        XCTAssertNil(
            database.data.cachedOrCreatedObject(entityName: .objectA, objectId: objectA0Id))
        XCTAssertNil(
            database.data.cachedOrCreatedObject(entityName: .objectA, objectId: objectA1Id))
        XCTAssertNil(
            database.data.cachedOrCreatedObject(entityName: .objectA, objectId: objectA2Id))

        do {
            // object_aを全て取得
            // objectA0にobjectB1、objectB0
            // objectA1にobjectB2

            let fetchedObjects = try await database.executor.fetchSyncedObjects(
                .init(selects: [
                    .init(
                        table: .objectA,
                        columnOrders: [.init(name: .objectId, order: .ascending)])
                ]))

            let aObjects = try XCTUnwrap(fetchedObjects[.objectA])

            XCTAssertEqual(aObjects.objects.count, 2)

            let objectA0 = try XCTUnwrap(aObjects.object(at: 0))
            let objectA0Relations = database.data.relationObjects(
                sourceObject: objectA0, relationName: .children)

            XCTAssertEqual(objectA0Relations.count, 2)
            XCTAssertEqual(objectA0Relations[0]?.id.stable, objectB1Id.stable)
            XCTAssertEqual(objectA0Relations[1]?.id.stable, objectB0Id.stable)

            let objectA1 = try XCTUnwrap(aObjects.object(at: 1))
            let objectA1Relations = database.data.relationObjects(
                sourceObject: objectA1, relationName: .children)

            XCTAssertEqual(objectA1Relations.count, 1)
            XCTAssertEqual(objectA1Relations[0]?.id.stable, objectB2Id.stable)
        }

        // キャッシュが残っていないことを確認
        XCTAssertNil(
            database.data.cachedOrCreatedObject(entityName: .objectA, objectId: objectA0Id))
        XCTAssertNil(
            database.data.cachedOrCreatedObject(entityName: .objectA, objectId: objectA1Id))
        XCTAssertNil(
            database.data.cachedOrCreatedObject(entityName: .objectA, objectId: objectA2Id))

        do {
            // objectB0をremove
            let objectB0 = try XCTUnwrap(insertedData[.objectB]?.array[0])
            objectB0.remove()

            let _ = try await database.executor.save()

            XCTAssertEqual(database.data.info.currentSaveId, 5)
        }

        do {
            // object_aを全て取得
            // objectA0にobjectB1
            // objectA1にobjectB2

            let fetchedObjects = try await database.executor.fetchSyncedObjects(
                .init(selects: [
                    .init(
                        table: .objectA,
                        columnOrders: [.init(name: .objectId, order: .ascending)])
                ]))

            let aObjects = try XCTUnwrap(fetchedObjects[.objectA])

            XCTAssertEqual(aObjects.objects.count, 2)

            let objectA0 = try XCTUnwrap(aObjects.object(at: 0))
            let objectA0Relations = database.data.relationObjects(
                sourceObject: objectA0, relationName: .children)
            XCTAssertEqual(objectA0Relations.count, 1)
            XCTAssertEqual(objectA0Relations[0]?.id.stable, objectB1Id.stable)

            let objectA1 = try XCTUnwrap(aObjects.object(at: 1))
            let objectA1Relations = database.data.relationObjects(
                sourceObject: objectA1, relationName: .children)
            XCTAssertEqual(objectA1Relations.count, 1)
            XCTAssertEqual(objectA1Relations[0]?.id.stable, objectB2Id.stable)
        }

        // キャッシュが残っていないことを確認
        XCTAssertNil(
            database.data.cachedOrCreatedObject(entityName: .objectA, objectId: objectA0Id))
        XCTAssertNil(
            database.data.cachedOrCreatedObject(entityName: .objectA, objectId: objectA1Id))
        XCTAssertNil(
            database.data.cachedOrCreatedObject(entityName: .objectA, objectId: objectA2Id))

        do {
            // objectB1をremove
            let objectB1 = try XCTUnwrap(insertedData[.objectB]?.array[1])
            objectB1.remove()

            let _ = try await database.executor.save()

            XCTAssertEqual(database.data.info.currentSaveId, 6)
        }

        do {
            // objectAを全て取得
            // objectA0に関連なし
            // objectA1にobjectB2

            let fetchedObjects = try await database.executor.fetchSyncedObjects(
                .init(selects: [
                    .init(
                        table: .objectA,
                        columnOrders: [.init(name: .objectId, order: .ascending)])
                ]))

            let aObjects = try XCTUnwrap(fetchedObjects[.objectA])
            XCTAssertEqual(aObjects.objects.count, 2)

            let objectA0 = try XCTUnwrap(aObjects.object(at: 0))
            let objectA0Relations = database.data.relationObjects(
                sourceObject: objectA0, relationName: .children)
            XCTAssertEqual(objectA0Relations.count, 0)

            let objectA1 = try XCTUnwrap(aObjects.object(at: 1))
            let objectA1Relations = database.data.relationObjects(
                sourceObject: objectA1, relationName: .children)
            XCTAssertEqual(objectA1Relations.count, 1)
            XCTAssertEqual(objectA1Relations[0]?.id.stable, objectB2Id.stable)
        }

        // キャッシュが残っていないことを確認
        XCTAssertNil(
            database.data.cachedOrCreatedObject(entityName: .objectA, objectId: objectA0Id))
        XCTAssertNil(
            database.data.cachedOrCreatedObject(entityName: .objectA, objectId: objectA1Id))
        XCTAssertNil(
            database.data.cachedOrCreatedObject(entityName: .objectA, objectId: objectA2Id))

        do {
            // obj_b2をremove
            let objectB2 = try XCTUnwrap(insertedData[.objectB]?.array[2])
            objectB2.remove()

            let _ = try await database.executor.save()

            XCTAssertEqual(database.data.info.currentSaveId, 7)
        }

        do {
            // object_bのオブジェクトをキャッシュから削除する
            insertedData[.objectB] = nil
        }

        // キャッシュが残っていないことを確認
        XCTAssertNil(
            database.data.cachedOrCreatedObject(entityName: .objectA, objectId: objectA0Id))
        XCTAssertNil(
            database.data.cachedOrCreatedObject(entityName: .objectA, objectId: objectA1Id))
        XCTAssertNil(
            database.data.cachedOrCreatedObject(entityName: .objectA, objectId: objectA2Id))
        XCTAssertNil(
            database.data.cachedOrCreatedObject(entityName: .objectB, objectId: objectB0Id))
        XCTAssertNil(
            database.data.cachedOrCreatedObject(entityName: .objectB, objectId: objectB1Id))
        XCTAssertNil(
            database.data.cachedOrCreatedObject(entityName: .objectB, objectId: objectB2Id))

        do {
            // object_aを全て取得
            // 関連は全て外れている

            let fetchedObjects = try await database.executor.fetchSyncedObjects(
                .init(selects: [
                    .init(
                        table: .objectA,
                        columnOrders: [.init(name: .objectId, order: .ascending)])
                ]))
            let aObjects = try XCTUnwrap(fetchedObjects[.objectA])

            XCTAssertEqual(aObjects.objects.count, 2)

            let objectA0 = try XCTUnwrap(aObjects.object(at: 0))
            let objectA1 = try XCTUnwrap(aObjects.object(at: 1))

            XCTAssertEqual(
                database.data.relationObjects(sourceObject: objectA0, relationName: .children)
                    .count, 0
            )
            XCTAssertEqual(
                database.data.relationObjects(sourceObject: objectA1, relationName: .children)
                    .count, 0
            )
        }
    }

    @MainActor
    func testObjectIdBecomesBothAfterCreateAndSave() async throws {
        let model = TestUtils.makeModel0_0_1()
        let (database, _) = try await TestUtils.makeDatabaseWithSetup(uuid: uuid, model: model)

        let object = database.data.createObject(entityName: .objectA)

        let temporaryId = try XCTUnwrap(object.id.temporary)
        XCTAssertNil(object.id.stable)

        let saved = try await database.executor.save()

        let expectedId = ObjectId.both(stable: .init(1), temporary: temporaryId)
        XCTAssertEqual(object.id, expectedId)

        let savedObject = try XCTUnwrap(saved[.objectA]?.objects[expectedId])
        XCTAssertEqual(savedObject.id, expectedId)
    }

    @MainActor
    func testSyncedObjectIdBecomesStableAfterRemakeTheDatabase() async throws {
        let model = TestUtils.makeModel0_0_1()
        let allAFetchOption = FetchOption(selects: [.init(table: .objectA)])

        do {
            let (database, _) = try await TestUtils.makeDatabaseWithSetup(uuid: uuid, model: model)
            let object = database.data.createObject(entityName: .objectA)
            _ = try await database.executor.save()

            let temporaryId = try XCTUnwrap(object.id.temporary)
            let expectedBothId = ObjectId.both(stable: .init(1), temporary: temporaryId)
            XCTAssertEqual(object.id, expectedBothId)

            let fetched = try await database.executor.fetchSyncedObjects(allAFetchOption)
            let aObjects = try XCTUnwrap(fetched[.objectA])
            let aObject0 = try XCTUnwrap(aObjects.object(at: 0))
            XCTAssertEqual(aObjects.objects.count, 1)
            XCTAssertEqual(aObject0.id, expectedBothId)
        }

        let (database, _) = try await TestUtils.makeDatabaseWithSetup(uuid: uuid, model: model)
        let fetched = try await database.executor.fetchSyncedObjects(allAFetchOption)
        let aObjects = try XCTUnwrap(fetched[.objectA])
        let aObject0 = try XCTUnwrap(aObjects.object(at: 0))

        XCTAssertEqual(aObjects.objects.count, 1)
        XCTAssertEqual(aObject0.id, .stable(.init(1)))
    }

    @MainActor
    func testReadOnlyObjectIdBecomesStableAfterRemakeTheDatabase() async throws {
        let model = TestUtils.makeModel0_0_1()
        let allAFetchOption = FetchOption(selects: [.init(table: .objectA)])

        do {
            let (database, _) = try await TestUtils.makeDatabaseWithSetup(uuid: uuid, model: model)
            let object = database.data.createObject(entityName: .objectA)
            _ = try await database.executor.save()

            let temporaryId = try XCTUnwrap(object.id.temporary)
            let expectedBothId = ObjectId.both(stable: .init(1), temporary: temporaryId)

            let fetched = try await database.executor.fetchReadOnlyObjects(allAFetchOption)
            let aObjects = try XCTUnwrap(fetched[.objectA])

            XCTAssertEqual(aObjects.objects.count, 1)
            XCTAssertEqual(aObjects.object(at: 0)?.id, expectedBothId)
        }

        let (database, _) = try await TestUtils.makeDatabaseWithSetup(uuid: uuid, model: model)
        let fetched = try await database.executor.fetchReadOnlyObjects(allAFetchOption)
        let aObjects = try XCTUnwrap(fetched[.objectA])

        XCTAssertEqual(aObjects.objects.count, 1)
        XCTAssertEqual(aObjects.object(at: 0)?.id, .stable(.init(1)))
    }

    @MainActor
    func testSyncedObjectRelationIdsReplaced() async throws {
        let model = TestUtils.makeModel0_0_1()

        do {
            let (database, _) = try await TestUtils.makeDatabaseWithSetup(uuid: uuid, model: model)

            let insertedData = try await database.executor.insertSyncedObjects(counts: [
                .objectA: 1, .objectB: 1,
            ])
            let objectA = try XCTUnwrap(insertedData[.objectA]?.objects.first?.value)
            let insertedObjectB = try XCTUnwrap(insertedData[.objectB]?.objects.first?.value)
            let createdObjectB = database.data.createObject(entityName: .objectB)
            let createdBTemporaryId = try XCTUnwrap(createdObjectB.id.temporary)

            objectA.setRelationObjects([insertedObjectB, createdObjectB], forName: .children)

            let preSavedRelationIds = try XCTUnwrap(objectA.relationIds[.children])

            XCTAssertEqual(preSavedRelationIds[0], .stable(.init(1)))
            XCTAssertEqual(preSavedRelationIds[1], .temporary(createdBTemporaryId))

            _ = try await database.executor.save()

            let postSavedRelationIds = try XCTUnwrap(objectA.relationIds[.children])

            // 最初からstableであればstableのまま
            XCTAssertEqual(postSavedRelationIds[0], .stable(.init(1)))
            // temporaryだったらbothになる
            XCTAssertEqual(
                postSavedRelationIds[1], .both(stable: .init(2), temporary: createdBTemporaryId))
        }

        do {
            let (database, _) = try await TestUtils.makeDatabaseWithSetup(uuid: uuid, model: model)

            let fetched = try await database.executor.fetchSyncedObjects(
                .init(selects: [.init(table: .objectA)]))
            let objects = try XCTUnwrap(fetched[.objectA])
            let objectA = try XCTUnwrap(objects.object(at: 0))

            let relationIds = try XCTUnwrap(objectA.relationIds[.children])

            XCTAssertEqual(relationIds[0], .stable(.init(1)))
            XCTAssertEqual(relationIds[1], .stable(.init(2)))
        }
    }
}
