import Foundation

public enum ObjectId: Sendable, Codable {
    case stable(_ stable: StableId)
    case both(stable: StableId, temporary: TemporaryId)
    case temporary(TemporaryId)

    init(stable: StableId, temporary: TemporaryId?) {
        if let temporary {
            self = .both(stable: stable, temporary: temporary)
        } else {
            self = .stable(stable)
        }
    }

    init(_ loadingId: LoadingObjectId) {
        switch loadingId {
        case let .stable(stableId):
            self = .stable(stableId)
        case let .both(stableId, temporaryId):
            self = .both(stable: stableId, temporary: temporaryId)
        }
    }
}

extension ObjectId {
    public var stable: StableId? {
        switch self {
        case .stable(let value), .both(let value, _):
            value
        case .temporary:
            nil
        }
    }

    public var temporary: TemporaryId? {
        switch self {
        case .stable:
            nil
        case .both(_, let value), .temporary(let value):
            value
        }
    }

    public var stableValue: SQLValue {
        if let stable {
            .integer(stable.rawValue)
        } else {
            .null
        }
    }

    public var temporaryValue: SQLValue {
        if let temporary {
            .text(temporary.rawValue)
        } else {
            .null
        }
    }
    public var isStable: Bool {
        stable != nil
    }

    public var isTemporary: Bool {
        stable == nil
    }
}

extension ObjectId: Equatable {
    public static func == (lhs: ObjectId, rhs: ObjectId) -> Bool {
        if let lhsTemporary = lhs.temporary, let rhsTemporary = rhs.temporary {
            return lhsTemporary == rhsTemporary
        } else if let lhsStable = lhs.stable, let rhsStable = rhs.stable {
            return lhsStable == rhsStable
        } else {
            return false
        }
    }
}

extension ObjectId: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .temporary(let temporaryId), .both(_, let temporaryId):
            hasher.combine(temporaryId)
        case .stable(let stableId):
            hasher.combine(stableId)
        }
    }
}

extension ObjectId: Comparable {
    public static func < (lhs: ObjectId, rhs: ObjectId) -> Bool {
        // temporaryは新しいのでstableより後
        // bothならstable扱いにしてstableとしての順番になる
        switch (lhs, rhs) {
        case (.temporary(let lhsTemporary), .temporary(let rhsTemporary)):
            return lhsTemporary < rhsTemporary
        case (.stable(let lhsStable), .stable(let rhsStable)):
            return lhsStable < rhsStable
        case (.both(let lhsStable, _), .both(let rhsStable, _)):
            return lhsStable < rhsStable
        case (.temporary, .stable):
            return false
        case (.stable, .temporary):
            return true
        case (.temporary, .both):
            return false
        case (.both, .temporary):
            return true
        case (.stable(let lhsStable), .both(let rhsStable, _)):
            return lhsStable < rhsStable
        case (.both(let lhsStable, _), .stable(let rhsStable)):
            return lhsStable < rhsStable
        }
    }
}

extension ObjectId: CustomStringConvertible {
    public var description: String {
        "{stable:" + self.stableValue.sqlStringValue + ", temporary:"
            + self.temporaryValue.sqlStringValue + "}"
    }
}
