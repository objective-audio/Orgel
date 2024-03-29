import Foundation
import Orgel

@OrgelObject
struct ObjectB: ObjectCodable {
    struct Attributes: AttributesCodable {
        var name: String = "empty_name"
    }

    struct Relations: RelationsCodable {
    }
}
