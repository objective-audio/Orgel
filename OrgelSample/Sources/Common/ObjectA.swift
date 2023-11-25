import Foundation
import Orgel

@OrgelObject
struct ObjectA: ObjectCodable {
    struct Attributes: AttributesCodable {
        var age: Int = 1
        var name: String = "empty_name"
    }

    struct Relations: RelationsCodable {
        var manyB: [ObjectB.Id]
    }
}
