import XCTest

@testable import Orgel

final class SQLValueInternalTests: XCTestCase {
    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
    }

    func testActionValues() {
        XCTAssertEqual(SQLValue.insertAction.textValue, "insert")
        XCTAssertEqual(SQLValue.updateAction.textValue, "update")
        XCTAssertEqual(SQLValue.removeAction.textValue, "remove")
    }
}
