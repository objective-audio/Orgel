import XCTest

@testable import Orgel

final class LoadedIdPoolTests: XCTestCase {
    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
    }

    func testEmpty() async {
        let pool = LoadedIdPool()

        await AssertNilAsync(await pool.get(for: TemporaryId("1"), entityName: .init("a")))
        await AssertNilAsync(await pool.get(for: StableId(1), entityName: .init("a")))
    }

    func testGet() async {
        let pool = LoadedIdPool()

        let stableId = StableId(1)
        let temporaryId = TemporaryId("1")
        let bothId = LoadingObjectId.both(stable: stableId, temporary: temporaryId)
        let entityName = Entity.Name("a")

        await pool.set(stable: stableId, temporary: temporaryId, entityName: entityName)

        await AssertEqualAsync(await pool.get(for: stableId, entityName: entityName), bothId)
        await AssertEqualAsync(await pool.get(for: temporaryId, entityName: entityName), bothId)

        await AssertNilAsync(await pool.get(for: .init("other-id"), entityName: entityName))
        await AssertNilAsync(await pool.get(for: .init(2), entityName: entityName))
        await AssertNilAsync(await pool.get(for: stableId, entityName: .init("other-name")))
        await AssertNilAsync(await pool.get(for: temporaryId, entityName: .init("other-name")))
    }

    func testClear() async {
        let pool = LoadedIdPool()

        let stableId = StableId(1)
        let temporaryId = TemporaryId("1")
        let bothId = LoadingObjectId.both(stable: stableId, temporary: temporaryId)
        let entityName = Entity.Name("a")

        await pool.set(stable: stableId, temporary: temporaryId, entityName: entityName)

        await AssertEqualAsync(await pool.get(for: stableId, entityName: entityName), bothId)

        await pool.clear()

        await AssertNilAsync(await pool.get(for: stableId, entityName: entityName))
    }
}
