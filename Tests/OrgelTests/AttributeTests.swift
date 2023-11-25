import XCTest

@testable import Orgel

final class AttributeTests: XCTestCase {
    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
    }

    func testInitIntegerSuccess() throws {
        let attribute = try Attribute(
            name: .init("integer_attr"), value: .integer(.notNull(1)))

        XCTAssertEqual(attribute.name.rawValue, "integer_attr")
        XCTAssertEqual(attribute.value, .integer(.notNull(1)))
        XCTAssertEqual(attribute.defaultValue, .integer(1))
        XCTAssertTrue(attribute.notNull)
        XCTAssertFalse(attribute.primary)
        XCTAssertFalse(attribute.unique)
    }

    func testInitReal() throws {
        let attribute = try Attribute(name: .init("real_attr"), value: .real(.allowNull(2.5)))

        XCTAssertEqual(attribute.name.rawValue, "real_attr")
        XCTAssertEqual(attribute.value, .real(.allowNull(2.5)))
        XCTAssertEqual(attribute.defaultValue, .real(2.5))
        XCTAssertFalse(attribute.notNull)
        XCTAssertFalse(attribute.primary)
        XCTAssertFalse(attribute.unique)
    }

    func testInitText() throws {
        let attribute = try Attribute(
            name: .init("text_attr"), value: .text(.allowNull("test_string")))

        XCTAssertEqual(attribute.name.rawValue, "text_attr")
        XCTAssertEqual(attribute.value, .text(.allowNull("test_string")))
        XCTAssertEqual(attribute.defaultValue, .text("test_string"))
        XCTAssertFalse(attribute.notNull)
        XCTAssertFalse(attribute.primary)
        XCTAssertFalse(attribute.unique)
    }

    func testInitBlob() throws {
        let data = Data([UInt8]([2, 4]))
        let attribute = try Attribute(name: .init("blob_attr"), value: .blob(.allowNull(data)))

        XCTAssertEqual(attribute.name.rawValue, "blob_attr")
        XCTAssertEqual(attribute.value, .blob(.allowNull(data)))

        XCTAssertEqual(attribute.defaultValue, .blob(data))

        if case let .blob(data) = attribute.defaultValue {
            XCTAssertEqual(data.count, 2)
            XCTAssertEqual(data[0], 2)
            XCTAssertEqual(data[1], 4)
        }

        XCTAssertFalse(attribute.notNull)
        XCTAssertFalse(attribute.primary)
        XCTAssertFalse(attribute.unique)
    }

    func testInitPkIdAttribute() throws {
        let attribute = Attribute.pkId

        XCTAssertEqual(attribute.name.rawValue, "pk_id")
        XCTAssertEqual(attribute.value, .integer(.allowNull(nil)))
        XCTAssertFalse(attribute.notNull)
        XCTAssertTrue(attribute.primary)
    }

    func testInitFailureNameIsEmpty() throws {
        XCTAssertThrowsError(try Attribute(name: .init(""), value: .integer(.allowNull(1))))
    }

    func testIntegerDefaultValue() throws {
        XCTAssertEqual(
            try Attribute(name: .init("allow_null"), value: .integer(.allowNull(101))).defaultValue,
            .integer(101))
        XCTAssertEqual(
            try Attribute(name: .init("null"), value: .integer(.allowNull(nil))).defaultValue, .null
        )
        XCTAssertEqual(
            try Attribute(name: .init("not_null"), value: .integer(.notNull(102))).defaultValue,
            .integer(102))
    }

    func testRealDefaultValue() throws {
        XCTAssertEqual(
            try Attribute(name: .init("allow_null"), value: .real(.allowNull(1.0))).defaultValue,
            .real(1.0))
        XCTAssertEqual(
            try Attribute(name: .init("null"), value: .real(.allowNull(nil))).defaultValue, .null
        )
        XCTAssertEqual(
            try Attribute(name: .init("not_null"), value: .real(.notNull(2.0))).defaultValue,
            .real(2.0))
    }

    func testTextDefaultValue() throws {
        XCTAssertEqual(
            try Attribute(name: .init("allow_null"), value: .text(.allowNull("allow_null_value")))
                .defaultValue,
            .text("allow_null_value"))
        XCTAssertEqual(
            try Attribute(name: .init("null"), value: .text(.allowNull(nil))).defaultValue, .null
        )
        XCTAssertEqual(
            try Attribute(name: .init("not_null"), value: .text(.notNull("not_null_value")))
                .defaultValue,
            .text("not_null_value"))
    }

    func testBlobDefaultValue() throws {
        let allowNullData = Data([UInt8]([0, 1]))
        let notNullData = Data([UInt8]([2, 3]))

        XCTAssertEqual(
            try Attribute(name: .init("allow_null"), value: .blob(.allowNull(allowNullData)))
                .defaultValue,
            .blob(allowNullData))
        XCTAssertEqual(
            try Attribute(name: .init("null"), value: .blob(.allowNull(nil))).defaultValue, .null
        )
        XCTAssertEqual(
            try Attribute(name: .init("not_null"), value: .blob(.notNull(notNullData)))
                .defaultValue,
            .blob(notNullData))
    }

    func testColumnNotNull() throws {
        let attribute = try Attribute(
            name: .init("test_name"), value: .text(.notNull("test_string")))

        let column = attribute.column
        XCTAssertEqual(column.name, .init("test_name"))
        XCTAssertEqual(column.valueType, .text)
        XCTAssertEqual(column.defaultValue, .text("test_string"))
        XCTAssertEqual(column.notNull, true)
        XCTAssertEqual(column.primary, false)
        XCTAssertEqual(column.unique, false)
    }

    func testColumnAllowNull() throws {
        let attribute = try Attribute(name: .init("test_name"), value: .text(.allowNull(nil)))

        let column = attribute.column
        XCTAssertEqual(column.name, .init("test_name"))
        XCTAssertEqual(column.valueType, .text)
        XCTAssertEqual(column.defaultValue, .null)
        XCTAssertEqual(column.notNull, false)
        XCTAssertEqual(column.primary, false)
        XCTAssertEqual(column.unique, false)
    }

    func testPkIdColumn() throws {
        let column = Attribute.pkId.column

        XCTAssertEqual(column.name, .init("pk_id"))
        XCTAssertEqual(column.valueType, .integer)
        XCTAssertEqual(column.defaultValue, .null)
        XCTAssertEqual(column.notNull, false)
        XCTAssertEqual(column.primary, true)
        XCTAssertEqual(column.unique, false)
    }

    func testFullColumn() throws {
        let attribute = try Attribute(
            name: .init("test_name"), value: .integer(.notNull(5)), primary: true, unique: true)

        let column = attribute.column
        XCTAssertEqual(column.name, .init("test_name"))
        XCTAssertEqual(column.valueType, .integer)
        XCTAssertEqual(column.defaultValue, .integer(5))
        XCTAssertEqual(column.notNull, true)
        XCTAssertEqual(column.primary, true)
        XCTAssertEqual(column.unique, true)
    }
}
