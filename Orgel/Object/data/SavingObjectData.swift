import Foundation

struct SavingObjectData: Sendable {
    let id: ObjectId
    let action: ObjectAction
    let attributes: [Attribute.Name: SQLValue]
    let relations: [Relation.Name: [ObjectId]]
}
