import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(OrgelMacros)
    import OrgelMacros

    let testMacros: [String: Macro.Type] = [
        "OrgelObject": OrgelObjectMacro.self
    ]
#endif

final class OrgelObjectTests: XCTestCase {
    func testMacro() throws {
        #if canImport(OrgelMacros)
            assertMacroExpansion(
                """
                @OrgelObject
                struct Object: ObjectCodable {
                    struct Attributes: AttributesCodable {
                        var integerValue: Int = 1
                        var realValue: Double = 2.0
                        var textValue: String = "3"
                        var blobValue: Data = Data([0, 1, 2])
                        
                        var optIntegerValue: Int?
                        var optRealValue: Double? = 4.0
                        var optTextValue: String?
                        var optBlobValue: Data?
                    }
                    
                    struct Relations: RelationsCodable {
                        var friend: ObjectC.Id?
                        var children: [ObjectB.Id] = []
                    }
                }
                """,
                expandedSource: """
                    struct Object: ObjectCodable {
                        struct Attributes: AttributesCodable {
                            var integerValue: Int = 1
                            var realValue: Double = 2.0
                            var textValue: String = "3"
                            var blobValue: Data = Data([0, 1, 2])
                            
                            var optIntegerValue: Int?
                            var optRealValue: Double? = 4.0
                            var optTextValue: String?
                            var optBlobValue: Data?
                        }
                        
                        struct Relations: RelationsCodable {
                            var friend: ObjectC.Id?
                            var children: [ObjectB.Id] = []
                        }

                        struct Id: RelationalId {
                            let rawId: ObjectId
                        }

                        let id: Id
                        var attributes: Attributes
                        var relations: Relations

                        static var entity: Model.EntityArgs {
                            .init(
                                name: .init(tableName),
                                attributes: [
                                    .init(name: .init("integerValue"), value: .integer(.notNull(1))),
                                    .init(name: .init("realValue"), value: .real(.notNull(2.0))),
                                    .init(name: .init("textValue"), value: .text(.notNull("3"))),
                                    .init(name: .init("blobValue"), value: .blob(.notNull(Data([0, 1, 2])))),
                                    .init(name: .init("optIntegerValue"), value: .integer(.allowNull(nil))),
                                    .init(name: .init("optRealValue"), value: .real(.allowNull(4.0))),
                                    .init(name: .init("optTextValue"), value: .text(.allowNull(nil))),
                                    .init(name: .init("optBlobValue"), value: .blob(.allowNull(nil)))
                                ],
                                relations: [
                                    .init(name: .init("friend"), target: .init("ObjectC"), many: false),
                                    .init(name: .init("children"), target: .init("ObjectB"), many: true)
                                ]
                            )
                        }
                    }
                    """,
                macros: testMacros
            )
        #else
            throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}
