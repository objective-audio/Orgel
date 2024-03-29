import Foundation

public protocol EntityResultData: Sendable {
    associatedtype Object

    var order: [ObjectId] { get }
    var objects: [ObjectId: Object] { get }
}

extension EntityResultData {
    public func object(at index: Int) -> Object? {
        guard index < order.count else { return nil }
        return objects[order[index]]
    }

    public var array: [Object] {
        order.compactMap { objects[$0] }
    }
}

public struct SyncedEntityResultData: EntityResultData {
    public var order: [ObjectId]
    public var objects: [ObjectId: SyncedObject]
}

public typealias SyncedResultData = [Entity.Name: SyncedEntityResultData]

extension SyncedResultData {
    @MainActor
    var relationStableIds: [Entity.Name: Set<StableId>] {
        reduce(
            into: .init(),
            { (partialResult, pair) in
                for object in pair.value.objects {
                    partialResult.formUnion(object.value.relationStableIds)
                }
            })
    }
}

public struct ReadOnlyEntityResultData: EntityResultData {
    public let order: [ObjectId]
    public let objects: [ObjectId: ReadOnlyObject]
}

public typealias ReadOnlyResultData = [Entity.Name: ReadOnlyEntityResultData]
