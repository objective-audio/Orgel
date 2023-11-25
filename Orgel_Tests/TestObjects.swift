import Foundation
import Orgel

struct ObjectA: ObjectCodable {
    struct Attributes: AttributesCodable {
        var age: Int
        var name: String?
        var weight: Double?
        var tall: Double?
        var data: Data?
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
}

struct ObjectB: ObjectCodable {
    struct Attributes: AttributesCodable {
        var fullname: String?
    }

    struct Relations: RelationsCodable {
        var parent: ObjectA.Id?
    }

    struct Id: RelationalId {
        let rawId: ObjectId
    }

    let id: Id
    var attributes: Attributes
    var relations: Relations
}

struct ObjectC: ObjectCodable {
    struct Attributes: AttributesCodable {
        var nickname: String?
    }

    struct Relations: RelationsCodable {
        var friend: ObjectA.Id?
    }

    struct Id: RelationalId {
        let rawId: ObjectId
    }

    let id: Id
    var attributes: Attributes
    var relations: Relations
}
