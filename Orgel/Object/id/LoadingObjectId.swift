import Foundation

enum LoadingObjectId: Sendable, Equatable {
    case stable(_ stable: StableId)
    case both(stable: StableId, temporary: TemporaryId)

    init(stable: StableId, temporary: TemporaryId?) {
        if let temporary {
            self = .both(stable: stable, temporary: temporary)
        } else {
            self = .stable(stable)
        }
    }
}

extension LoadingObjectId {
    var stable: StableId {
        switch self {
        case .stable(let stable), .both(let stable, _):
            stable
        }
    }

    var temporary: TemporaryId? {
        switch self {
        case .stable:
            nil
        case let .both(_, temporary):
            temporary
        }
    }

    var objectId: ObjectId {
        .init(self)
    }
}
