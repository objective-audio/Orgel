import Foundation
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

private enum IntegerType: String {
    case Int
    case Int8
    case Int16
    case Int32
    case Int64
    case UInt
    case UInt8
    case UInt16
    case UInt32
    case UInt64
}

private enum RealType: String {
    case Double
    case Float
}

private struct OrgelObjectModel {
    struct Attribute {
        enum ValueType: String {
            case integer
            case real
            case text
            case blob
        }

        let name: String
        let valueType: ValueType
        let isOptional: Bool
        let initialValue: String
    }

    struct Relation {
        let name: String
        let target: String
        let many: Bool
    }

    var attributes: [Attribute] = []
    var relations: [Relation] = []
}

extension OrgelObjectModel.Attribute.ValueType {
    init?(_ typeName: String) {
        if IntegerType(rawValue: typeName) != nil {
            self = .integer
        } else if RealType(rawValue: typeName) != nil {
            self = .real
        } else if typeName == "String" {
            self = .text
        } else if typeName == "Data" {
            self = .blob
        } else {
            return nil
        }
    }
}

extension OrgelObjectModel.Attribute {
    var macroText: String {
        "            .init(name: .init(\"\(name)\"), value: .\(valueType.rawValue)(.\(macroNullText)(\(macroInitialValueText))))"
    }

    var macroNullText: String { isOptional ? "allowNull" : "notNull" }
    var macroInitialValueText: String { initialValue.isEmpty ? "nil" : initialValue }
}

extension OrgelObjectModel.Relation {
    var macroText: String {
        "            .init(name: .init(\"\(name)\"), target: .init(\"\(target)\"), many: \(many))"
    }
}

public struct OrgelObjectMacro: MemberMacro {
    enum OrgelError: Error {
        case output(String)

        case objectIsNotStruct
        case objectCodableNotFound
        case attributesCodableNotFound
        case relationsCodableNotFound
        case notAttributes
        case notRelations
        case attributeNotVariable
        case attributeNameNotFound
        case attributeTypeAnnotationNotFound
        case getAttributeFailed(String)
        case relationNotVariable
        case relationNameNotFound
        case relationTypeAnnotationNotFound
        case getRelationFailed(String)
        case initialIntValueNotFound
        case initialRealValueNotFound
        case invalidAttributeOptionalType(String)
        case invalidAttributeIdentifierType(String)
        case invalidRelationArrayType(String)
        case invalidRelationOptionalType(String)
        case unknown
    }

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let rootStructDecl = declaration.as(StructDeclSyntax.self) else {
            throw OrgelError.objectIsNotStruct
        }

        guard let rootInheritanceClauseSyntax = rootStructDecl.inheritanceClause,
            containsInheritanceClause(rootInheritanceClauseSyntax, typeName: "ObjectCodable")
        else {
            throw OrgelError.objectCodableNotFound
        }

        var model: OrgelObjectModel = .init()

        for rootMemberSyntax in rootStructDecl.memberBlock.members {
            guard let structMember = rootMemberSyntax.decl.as(StructDeclSyntax.self) else {
                continue
            }

            if structMember.name.text == "Attributes" {
                model.attributes = try getAttributes(structMember)
            } else if structMember.name.text == "Relations" {
                model.relations = try getRelations(structMember)
            }
        }

        return [
            """
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
            \(raw: model.attributes.map(\.macroText).joined(separator: ",\n"))
                    ],
                    relations: [
            \(raw: model.relations.map(\.macroText).joined(separator: ",\n"))
                    ]
                )
            }
            """
        ]
    }

    private static func getAttributes(_ attributesStruct: StructDeclSyntax) throws
        -> [OrgelObjectModel.Attribute]
    {
        guard attributesStruct.name.text == "Attributes" else {
            throw OrgelError.notAttributes
        }

        guard let inheritanceClause = attributesStruct.inheritanceClause,
            containsInheritanceClause(inheritanceClause, typeName: "AttributesCodable")
        else {
            throw OrgelError.attributesCodableNotFound
        }

        var result: [OrgelObjectModel.Attribute] = []

        for attributeMember in attributesStruct.memberBlock.members {
            guard let variable = attributeMember.decl.as(VariableDeclSyntax.self) else {
                throw OrgelError.attributeNotVariable
            }

            for binding in variable.bindings {
                result.append(try getAttribute(binding))
            }
        }

        return result
    }

    private static func getAttribute(_ binding: PatternBindingListSyntax.Element) throws
        -> OrgelObjectModel.Attribute
    {
        guard let attributeName = binding.pattern.as(IdentifierPatternSyntax.self) else {
            throw OrgelError.attributeNameNotFound
        }

        guard let typeAnnotation = binding.typeAnnotation else {
            throw OrgelError.attributeTypeAnnotationNotFound
        }

        var initialValue: String = ""

        if let initializer = binding.initializer {
            initialValue = initializer.value.description
        }

        if let optionalType = typeAnnotation.type.as(OptionalTypeSyntax.self) {
            let typeName = optionalType.wrappedType.trimmed.description
            guard let valueType = OrgelObjectModel.Attribute.ValueType(typeName) else {
                throw OrgelError.invalidAttributeOptionalType(typeName)
            }
            return .init(
                name: attributeName.description, valueType: valueType, isOptional: true,
                initialValue: initialValue)
        } else if let identifierType = typeAnnotation.type.as(IdentifierTypeSyntax.self) {
            let typeName = identifierType.trimmed.description
            guard let valueType = OrgelObjectModel.Attribute.ValueType(typeName) else {
                throw OrgelError.invalidAttributeIdentifierType(typeName)
            }
            return .init(
                name: attributeName.description, valueType: valueType, isOptional: false,
                initialValue: initialValue)
        } else {
            throw OrgelError.getAttributeFailed(binding.description)
        }
    }

    private static func getRelations(_ relationsStruct: StructDeclSyntax) throws
        -> [OrgelObjectModel.Relation]
    {
        guard relationsStruct.name.text == "Relations" else {
            throw OrgelError.notRelations
        }

        guard let inheritanceClause = relationsStruct.inheritanceClause,
            containsInheritanceClause(inheritanceClause, typeName: "RelationsCodable")
        else {
            throw OrgelError.relationsCodableNotFound
        }

        var result: [OrgelObjectModel.Relation] = []

        for relationMember in relationsStruct.memberBlock.members {
            guard let variable = relationMember.decl.as(VariableDeclSyntax.self) else {
                throw OrgelError.relationNotVariable
            }

            for binding in variable.bindings {
                result.append(try getRelation(binding))
            }
        }

        return result
    }

    private static func getRelation(_ binding: PatternBindingListSyntax.Element) throws
        -> OrgelObjectModel.Relation
    {
        guard let relationName = binding.pattern.as(IdentifierPatternSyntax.self) else {
            throw OrgelError.relationNameNotFound
        }

        guard let typeAnnotation = binding.typeAnnotation else {
            throw OrgelError.relationTypeAnnotationNotFound
        }

        if let arrayType = typeAnnotation.type.as(ArrayTypeSyntax.self) {
            guard let typeElement = arrayType.element.as(MemberTypeSyntax.self),
                typeElement.name.text == "Id"
            else {
                throw OrgelError.invalidRelationArrayType(arrayType.description)
            }
            return .init(
                name: relationName.description, target: typeElement.baseType.description, many: true
            )
        } else if let optionalType = typeAnnotation.type.as(OptionalTypeSyntax.self) {
            guard let wrappedType = optionalType.wrappedType.as(MemberTypeSyntax.self),
                wrappedType.name.text == "Id"
            else {
                throw OrgelError.invalidRelationOptionalType(optionalType.description)
            }
            return .init(
                name: relationName.description, target: wrappedType.baseType.description,
                many: false
            )
        } else {
            throw OrgelError.getRelationFailed(binding.description)
        }
    }

    private static func containsInheritanceClause(
        _ syntax: InheritanceClauseSyntax, typeName: String
    ) -> Bool {
        guard
            syntax.inheritedTypes.contains(where: { typeSyntax in
                typeSyntax.tokens(viewMode: .all).contains { tokenSyntax in
                    tokenSyntax.text == typeName
                }
            })
        else {
            return false
        }

        return true
    }
}

@main
struct OrgelObjectPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        OrgelObjectMacro.self
    ]
}
