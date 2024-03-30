import XCTest

@testable import Orgel

final class SQLExpressionInternalTests: XCTestCase {
    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
    }

    func testCompareWithParameterName() {
        XCTAssertEqual(
            SQLExpression.compare(.init("abc"), .equal, .name(.init("def")))
                .sqlStringValue, "abc = :def")
    }

    func testCompareWithParameterValue() {
        XCTAssertEqual(
            SQLExpression.compare(.init("abc"), .equal, .value(.text("ghi")))
                .sqlStringValue, "abc = 'ghi'")
    }

    func testInWithTextValues() {
        let inExpr = SQLExpression.in(
            field: .column(.init("test_column")),
            source: .values([.text("value_a"), .text("value_b")]))
        XCTAssertEqual(inExpr.sqlStringValue, "test_column IN ('value_a', 'value_b')")
    }

    func testInWithIntegerValues() {
        let inExpr = SQLExpression.in(
            field: .column(.init("test_column")), source: .values([.integer(1), .integer(2)]))
        XCTAssertEqual(inExpr.sqlStringValue, "test_column IN (1, 2)")
    }

    func testInWithSelect() {
        let inExpr = SQLExpression.in(
            field: .column(.init("test_column")),
            source: .select(.init(table: .init("test_table"), field: .column(.init("column_a")))))
        XCTAssertEqual(inExpr.sqlStringValue, "test_column IN (SELECT column_a FROM test_table)")
    }

    func testInWithIds() {
        let inExpr = SQLExpression.in(
            field: .column(.init("test_column")), source: .ids([.init(1), .init(2)]))
        XCTAssertEqual(inExpr.sqlStringValue, "test_column IN (1, 2)")
    }
}
