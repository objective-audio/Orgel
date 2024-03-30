import Orgel
import XCTest

final class VersionTests: XCTestCase {
    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
    }

    func testInitWithString() throws {
        let version = try Version("1.2.3")

        XCTAssertEqual(version.numbers.count, 3)

        let numbers = version.numbers
        XCTAssertEqual(numbers[0], 1)
        XCTAssertEqual(numbers[1], 2)
        XCTAssertEqual(numbers[2], 3)

        XCTAssertEqual(version.stringValue, "1.2.3")
    }

    func testInitWithNumbers() throws {
        let version = try Version([5, 4, 3, 2])

        XCTAssertEqual(version.numbers.count, 4)

        let numbers = version.numbers
        XCTAssertEqual(numbers[0], 5)
        XCTAssertEqual(numbers[1], 4)
        XCTAssertEqual(numbers[2], 3)
        XCTAssertEqual(numbers[3], 2)

        XCTAssertEqual(version.stringValue, "5.4.3.2")
    }

    func testInitFailed() {
        XCTAssertThrowsError(try Version([]))
        XCTAssertThrowsError(try Version(""))
        XCTAssertThrowsError(try Version("-1"))
        XCTAssertThrowsError(try Version("1.-2"))
        XCTAssertThrowsError(try Version("."))
        XCTAssertThrowsError(try Version("1."))
        XCTAssertThrowsError(try Version(".1"))
    }

    func testEqual() throws {
        let ver1_2_3a = try Version("1.2.3")
        let ver1_2_3b = try Version("1.2.3")

        XCTAssertEqual(ver1_2_3a, ver1_2_3b)

        let ver1_2_0 = try Version("1.2.0")
        let ver1_2 = try Version("1.2")

        XCTAssertEqual(ver1_2_0, ver1_2)

        let ver1_5_3 = try Version("1.5.3")

        XCTAssertNotEqual(ver1_2_3a, ver1_5_3)
    }

    func testLess() throws {
        let ver1_2_3 = try Version("1.2.3")
        let ver1_2_4 = try Version("1.2.4")

        XCTAssertTrue(ver1_2_3 < ver1_2_4)

        let ver1_2_5a = try Version("1.2.5")
        let ver1_2_5b = try Version("1.2.5")

        XCTAssertFalse(ver1_2_5a < ver1_2_5b)
    }

    func testLessOrEqual() throws {
        let ver1_2_3 = try Version("1.2.3")
        let ver1_2_4 = try Version("1.2.4")

        XCTAssertTrue(ver1_2_3 <= ver1_2_4)

        let ver1_2_5a = try Version("1.2.5")
        let ver1_2_5b = try Version("1.2.5")

        XCTAssertTrue(ver1_2_5a <= ver1_2_5b)
    }

    func testGreater() throws {
        let ver1_2_4 = try Version("1.2.4")
        let ver1_2_3 = try Version("1.2.3")

        XCTAssertTrue(ver1_2_4 > ver1_2_3)

        let ver1_2_5a = try Version("1.2.5")
        let ver1_2_5b = try Version("1.2.5")

        XCTAssertFalse(ver1_2_5a > ver1_2_5b)
    }

    func testGreaterOrEqual() throws {
        let ver1_2_4 = try Version("1.2.4")
        let ver1_2_3 = try Version("1.2.3")

        XCTAssertTrue(ver1_2_4 >= ver1_2_3)

        let ver1_2_5a = try Version("1.2.5")
        let ver1_2_5b = try Version("1.2.5")

        XCTAssertTrue(ver1_2_5a >= ver1_2_5b)
    }
}
