import Foundation
import Orgel

extension Entity.Name {
    static let a: Entity.Name = ObjectA.entity.name
    static let b: Entity.Name = ObjectB.entity.name
}

extension Attribute.Name {
    static let name: Attribute.Name = .init("name")
}

enum SampleModel {
    static func make() -> Model {
        return try! .init(
            version: try! .init("1.0.0"),
            entities: [ObjectA.entity, ObjectB.entity], indices: [])
    }
}
