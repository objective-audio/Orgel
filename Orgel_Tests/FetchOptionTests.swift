import XCTest

@testable import Orgel

final class FetchOptionTests: XCTestCase {
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testInitWithSelectOptions() throws {
        let option = FetchOption(selects: [
            .init(table: .init("table_a")), .init(table: .init("table_b")),
        ])

        XCTAssertEqual(option.selects.count, 2)
        XCTAssertEqual(option.selects[.init("table_a")]?.table.sqlStringValue, "table_a")
        XCTAssertEqual(option.selects[.init("table_b")]?.table.sqlStringValue, "table_b")
    }

    func testAddSelect() throws {
        var option = FetchOption()

        try option.addSelect(.init(table: .init("table_a"))).get()
        try option.addSelect(.init(table: .init("table_b"))).get()

        XCTAssertEqual(option.selects.count, 2)
        XCTAssertEqual(option.selects[.init("table_a")]?.table.sqlStringValue, "table_a")
        XCTAssertEqual(option.selects[.init("table_b")]?.table.sqlStringValue, "table_b")
    }

    func testAddSelectFailed() throws {
        var option = FetchOption()

        try option.addSelect(.init(table: .init("table_a"))).get()
        XCTAssertThrowsError(try option.addSelect(.init(table: .init("table_a"))).get())
    }
}
