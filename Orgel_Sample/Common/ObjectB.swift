import Foundation
import Orgel

struct ObjectB: ObjectCodable {
    struct Attributes: AttributesCodable {
        var name: String
    }

    struct Relations: RelationsCodable {
    }

    struct Id: RelationalId {
        let rawId: ObjectId
    }

    let id: Id
    var attributes: Attributes
    var relations: Relations
}
