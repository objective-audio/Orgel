import Orgel
import XCTest

final class SQLSelectTests: XCTestCase {
    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
    }

    func testRangeIsEmpty() {
        XCTAssertTrue(SQLSelect.Range.empty.isEmpty)
        XCTAssertFalse(SQLSelect.Range(location: 1, length: 2).isEmpty)
    }
}
