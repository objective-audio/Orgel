import Foundation

struct SyncedObjectId {
    private enum RawValue {
        case stable(_ stable: StableId)
        case both(stable: StableId, temporary: SyncedTemporaryId)
        case temporary(_ temporary: SyncedTemporaryId)
    }

    private var rawValue: RawValue?

    var stable: StableId? {
        switch rawValue {
        case .stable(let value), .both(let value, _):
            value
        case .temporary:
            nil
        case .none:
            fatalError()
        }
    }

    var temporary: TemporaryId? {
        switch rawValue {
        case .stable:
            nil
        case .both(_, let value), .temporary(let value):
            value.temporaryId
        case .none:
            fatalError()
        }
    }

    init() {
        rawValue = nil
    }

    init(stable: StableId, temporary: String? = nil) {
        if let temporary {
            rawValue = .both(stable: stable, temporary: .init(temporary))
        } else {
            rawValue = .stable(stable)
        }
    }

    init(temporary: String) {
        rawValue = .temporary(.init(temporary))
    }

    mutating func setNewTemporary() {
        rawValue = .temporary(.init())
    }

    mutating func replaceId(_ loadingId: LoadingObjectId) {
        if hasValue {
            precondition(loadingId.temporary == nil || (loadingId.temporary == self.temporary))
        }

        switch loadingId {
        case let .both(stable, temporary):
            rawValue = .both(stable: stable, temporary: .init(temporary.rawValue))
        case let .stable(stable):
            rawValue = .stable(stable)
        }
    }

    var objectId: ObjectId {
        switch rawValue {
        case .stable(let stable):
            .stable(stable)
        case .both(let stable, let temporary):
            .both(stable: stable, temporary: temporary.temporaryId)
        case .temporary(let temporary):
            .temporary(temporary.temporaryId)
        case .none:
            fatalError()
        }
    }

    var hasValue: Bool {
        rawValue != nil
    }
}

extension SyncedObjectId {
    var stableValue: SQLValue {
        if let stable {
            .integer(stable.rawValue)
        } else {
            .null
        }
    }

    var temporaryValue: SQLValue {
        if let temporary {
            .text(temporary.rawValue)
        } else {
            .null
        }
    }
}

extension SyncedObjectId: Equatable {
    public static func == (lhs: SyncedObjectId, rhs: SyncedObjectId) -> Bool {
        lhs.objectId == rhs.objectId
    }
}

private enum SyncedTemporaryId {
    class InstanceId {}

    case instance(InstanceId)
    case string(String)

    init(_ stringValue: String) {
        self = .string(stringValue)
    }

    init() {
        self = .instance(.init())
    }

    var stringValue: String {
        switch self {
        case .instance(let rawId):
            String(Int(bitPattern: ObjectIdentifier(rawId)))
        case .string(let string):
            string
        }
    }

    var temporaryId: TemporaryId { .init(stringValue) }
}
