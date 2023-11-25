import Foundation
import Orgel

struct ObjectA: ObjectCodable {
    struct Attributes: AttributesCodable {
        var age: Int
        var name: String
    }

    struct Relations: RelationsCodable {
        var manyB: [ObjectB.Id]
    }

    struct Id: RelationalId {
        let rawId: ObjectId
    }

    let id: Id
    var attributes: Attributes
    var relations: Relations
}
