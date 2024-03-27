import Foundation
import Orgel
import OrgelObject

@OrgelObject
struct ObjectB: ObjectCodable {
    struct Attributes: AttributesCodable {
        var name: String = "empty_name"
    }

    struct Relations: RelationsCodable {
    }
}
