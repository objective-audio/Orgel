import Foundation
import XCTest

@testable import Orgel

extension Entity.Name {
    static let objectA: Entity.Name = ObjectA.entityName
    static let objectB: Entity.Name = ObjectB.entityName
    static let objectC: Entity.Name = ObjectC.entityName
}

extension Attribute.Name {
    static let age: Attribute.Name = .init("age")
    static let name: Attribute.Name = .init("name")
    static let weight: Attribute.Name = .init("weight")
    static let tall: Attribute.Name = .init("tall")
    static let data: Attribute.Name = .init("data")

    static let fullname: Attribute.Name = .init("fullname")

    static let nickname: Attribute.Name = .init("nickname")
}

extension Relation.Name {
    static let children: Relation.Name = .init("children")
    static let friend: Relation.Name = .init("friend")
    static let parent: Relation.Name = .init("parent")
}

extension Index.Name {
    static let objectAName: Index.Name = .init("ObjectA_name")
    static let objectAOthers: Index.Name = .init("ObjectA_others")
    static let objectBName: Index.Name = .init("ObjectB_name")
}

extension SQLTable {
    static let objectA: SQLTable = ObjectA.table
    static let objectB: SQLTable = ObjectB.table
    static let objectC: SQLTable = ObjectC.table
}

extension SQLColumn.Name {
    enum System {
        static let sql: SQLColumn.Name = .init("sql")
        static let name: SQLColumn.Name = .init("name")
        static let tblName: SQLColumn.Name = .init("tbl_name")
        static let rootpage: SQLColumn.Name = .init("rootpage")
        static let pk: SQLColumn.Name = .init("pk")
        static let dfltValue: SQLColumn.Name = .init("dflt_value")
        static let notnull: SQLColumn.Name = .init("notnull")
        static let cid: SQLColumn.Name = .init("cid")
        static let type: SQLColumn.Name = .init("type")
    }

    static let age: SQLColumn.Name = .init("age")
    static let name: SQLColumn.Name = .init("name")
    static let weight: SQLColumn.Name = .init("weight")
    static let tall: SQLColumn.Name = .init("tall")
    static let data: SQLColumn.Name = .init("data")

    static let fullname: SQLColumn.Name = .init("fullname")

    static let nickname: SQLColumn.Name = .init("nickname")
}

extension SQLParameter.Name {
    static let age: SQLParameter.Name = .init("age")
    static let name: SQLParameter.Name = .init("name")
    static let weight: SQLParameter.Name = .init("weight")

    static let fullname: SQLParameter.Name = .init("fullname")

    static let nickname: SQLParameter.Name = .init("nickname")
}

enum TestUtils {
    static func databaseUrl(uuid: UUID) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("/db_test_" + uuid.uuidString + ".db")
    }

    static func makeAndOpenExecutor(uuid: UUID) async -> SQLiteExecutor {
        let executor = SQLiteExecutor(url: databaseUrl(uuid: uuid))
        let _ = await executor.open()
        return executor
    }

    static func makeDatabaseWithSetup(uuid: UUID, model: Model) async throws -> (
        OrgelContainer, SQLiteExecutor
    ) {
        let sqliteExecutor = SQLiteExecutor(url: databaseUrl(uuid: uuid))
        let info = try await sqliteExecutor.setup(model: model)
        let data = await OrgelData(info: info, model: model)
        let executor = OrgelExecutor(model: model, data: data, sqliteExecutor: sqliteExecutor)
        return (.init(executor: executor, model: model, data: data), sqliteExecutor)
    }

    static func deleteFile(uuid: UUID) {
        do {
            if FileManager.default.fileExists(atPath: databaseUrl(uuid: uuid).path) {
                try FileManager.default.removeItem(at: databaseUrl(uuid: uuid))
            }
        } catch {
            print("\(error)")
        }
    }

    static func makeModel0_0_0() -> Model {
        let version = try! Version("0.0.0")
        return try! .init(version: version, entities: [], indices: [])
    }

    static func makeModel0_0_1() -> Model {
        let version = try! Version("0.0.1")

        let objectA = Model.EntityArgs(
            name: .objectA,
            attributes: [
                .init(name: .age, value: .integer(.notNull(10))),
                .init(name: .name, value: .text(.allowNull("default_value"))),
                .init(name: .weight, value: .real(.allowNull(65.4))),
                .init(name: .data, value: .blob(.allowNull(nil))),
            ], relations: [.init(name: .children, target: .objectB, many: true)])

        let objectB = Model.EntityArgs(
            name: .objectB,
            attributes: [.init(name: .fullname, value: .text(.allowNull(nil)))],
            relations: [])

        let entities = [objectA, objectB]

        let objectANameIndex = Model.IndexArgs(
            name: .objectAName, entity: .objectA, attributes: [.name])
        let objectAOthersIndex = Model.IndexArgs(
            name: .objectAOthers, entity: .objectA,
            attributes: [.age, .weight])
        let indices = [objectANameIndex, objectAOthersIndex]

        return try! .init(version: version, entities: entities, indices: indices)
    }

    static func makeModel0_0_2() -> Model {
        let version = try! Version("0.0.2")

        let entities = [ObjectA.entity, ObjectB.entity, ObjectC.entity]

        let objectANameIndex = Model.IndexArgs(
            name: .objectAName, entity: .objectA, attributes: [.name])
        let objectAOthersIndex = Model.IndexArgs(
            name: .objectAOthers, entity: .objectA,
            attributes: [.age, .weight])
        let objectBNameIndex = Model.IndexArgs(
            name: .objectBName, entity: .objectB, attributes: [.fullname])
        let indices = [objectANameIndex, objectAOthersIndex, objectBNameIndex]

        return try! .init(version: version, entities: entities, indices: indices)
    }
}

func AssertTrueAsync(
    _ expression: @autoclosure () async throws -> Bool, file: StaticString = #filePath,
    line: UInt = #line
) async rethrows {
    let result = try await expression()
    XCTAssertTrue(result, file: file, line: line)
}

func AssertFalseAsync(
    _ expression: @autoclosure () async throws -> Bool, file: StaticString = #filePath,
    line: UInt = #line
) async rethrows {
    let result = try await expression()
    XCTAssertFalse(result, file: file, line: line)
}

func AssertNilAsync(
    _ expression: @autoclosure () async throws -> Any?, file: StaticString = #filePath,
    line: UInt = #line
) async rethrows {
    let result = try await expression()
    XCTAssertNil(result, file: file, line: line)
}

func AssertNotNilAsync(
    _ expression: @autoclosure () async throws -> Any?, file: StaticString = #filePath,
    line: UInt = #line
) async rethrows {
    let result = try await expression()
    XCTAssertNotNil(result, file: file, line: line)
}

func AssertEqualAsync<T>(
    _ expression1: @autoclosure () async throws -> T,
    _ expression2: @autoclosure () async throws -> T, file: StaticString = #filePath,
    line: UInt = #line
) async rethrows where T: Equatable {
    let result1 = try await expression1()
    let result2 = try await expression2()
    XCTAssertEqual(result1, result2, file: file, line: line)
}

func AssertNotEqualAsync<T>(
    _ expression1: @autoclosure () async throws -> T,
    _ expression2: @autoclosure () async throws -> T, file: StaticString = #filePath,
    line: UInt = #line
) async rethrows where T: Equatable {
    let result1 = try await expression1()
    let result2 = try await expression2()
    XCTAssertNotEqual(result1, result2, file: file, line: line)
}

func AssertThrowsErrorAsync(
    _ expression: @autoclosure () async throws -> Void, file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        try await expression()
        XCTFail(file: file, line: line)
    } catch {}
}

actor SleeperMock: Sleeping {
    private typealias Continuation = CheckedContinuation<Void, Error>
    private(set) var expectation: XCTestExpectation = .init()
    private var continuation: Continuation?

    deinit {
        expectation.fulfill()
    }

    func sleep() async throws {
        try await withCheckedThrowingContinuation {
            (checkedContinuation: Continuation) in
            self.continuation = checkedContinuation
            self.expectation.fulfill()
        }
    }

    /// expectationがfulfillされた後に呼んでresumeする
    func resume(
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        guard let continuation else {
            XCTFail(file: file, line: line)
            return
        }

        expectation = .init()
        self.continuation = nil
        continuation.resume()
    }
}
