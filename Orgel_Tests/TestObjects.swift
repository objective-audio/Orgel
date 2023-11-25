import Foundation
import Orgel
import OrgelObject

@OrgelObject
struct ObjectA: ObjectCodable {
    struct Attributes: AttributesCodable {
        var age: Int = 10
        var name: String? = "default_value"
        var weight: Double? = 65.4
        var tall: Double? = 172.4
        var data: Data?
    }

    struct Relations: RelationsCodable {
        var friend: ObjectC.Id?
        var children: [ObjectB.Id] = []
    }
}

@OrgelObject
struct ObjectB: ObjectCodable {
    struct Attributes: AttributesCodable {
        var fullname: String?
    }

    struct Relations: RelationsCodable {
        var parent: ObjectA.Id?
    }
}

@OrgelObject
struct ObjectC: ObjectCodable {
    struct Attributes: AttributesCodable {
        var nickname: String?
    }

    struct Relations: RelationsCodable {
        var friend: ObjectA.Id?
    }
}
