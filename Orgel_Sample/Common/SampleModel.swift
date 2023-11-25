import Foundation
import Orgel

extension Entity.Name {
    static let a: Entity.Name = .init("entity_a")
    static let b: Entity.Name = .init("entity_b")
}

extension Attribute.Name {
    static let age: Attribute.Name = .init("age")
    static let name: Attribute.Name = .init("name")
}

extension Relation.Name {
    static let manyB: Relation.Name = .init("b")
}

enum SampleModel {
    static func make() -> Model {
        return try! .init(
            version: try! .init("1.0.0"),
            entities: [
                .init(
                    name: .a,
                    attributes: [
                        .init(name: .age, value: .integer(.notNull(1))),
                        .init(name: .name, value: .text(.notNull("empty_name"))),
                    ],
                    relations: [
                        .init(name: .manyB, target: .b, many: true)
                    ]),
                .init(
                    name: .b,
                    attributes: [.init(name: .name, value: .text(.notNull("empty_name")))],
                    relations: []),
            ], indices: [])
    }
}
