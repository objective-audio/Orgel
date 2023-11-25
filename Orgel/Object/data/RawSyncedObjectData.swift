import Foundation

enum RawSyncedObjectData {
    enum Updating {
        case saved
        case changed
        case saving
    }

    struct Available {
        enum State {
            struct Created {
                enum Updating {
                    case created
                    case saving
                    case changed
                }

                var updating: Updating
            }

            struct Saved {
                enum State {
                    case inserted
                    case updated
                }

                var state: State
                var saveId: Int64
                var updating: Updating
            }

            case created(Created)
            case saved(Saved)
        }

        var state: State
        var attributes: [Attribute.Name: SQLValue]
        var relationIds: [Relation.Name: [ObjectId]]
    }

    struct Unavailable {
        enum State {
            struct Aborted {
                enum Updating {
                    case aborted
                    case saving
                    case changed
                }

                var updating: Updating
            }

            struct Removed {
                var saveId: Int64
                var updating: Updating
            }

            case aborted(Aborted)
            case removed(Removed)
        }

        var state: State
    }

    case available(Available)
    case unavailable(Unavailable)
}

extension RawSyncedObjectData {
    mutating func didChange() {
        switch self {
        case .available(var available):
            switch available.state {
            case .created(let created):
                switch created.updating {
                case .created, .changed:
                    break
                case .saving:
                    available.state = .created(.init(updating: .changed))
                    self = .available(available)
                }
            case .saved(let saved):
                switch saved.state {
                case .inserted, .updated:
                    switch saved.updating {
                    case .changed:
                        break
                    case .saved, .saving:
                        available.state = .saved(
                            .init(state: .updated, saveId: saved.saveId, updating: .changed))
                        self = .available(available)
                    }
                }
            }
        case .unavailable:
            fatalError()
        }
    }

    mutating func remove() {
        switch self {
        case .available(let available):
            switch available.state {
            case .created(let created):
                switch created.updating {
                case .created:
                    self = .unavailable(.init(state: .aborted(.init(updating: .aborted))))
                case .changed, .saving:
                    self = .unavailable(.init(state: .aborted(.init(updating: .changed))))
                }
            case .saved(let saved):
                self = .unavailable(
                    .init(state: .removed(.init(saveId: saved.saveId, updating: .changed))))
            }
        case .unavailable:
            break
        }
    }

    // purgeされたときに1にするために呼ばれる
    mutating func setSaveId(_ saveId: Int64) {
        switch self {
        case .available(var available):
            switch available.state {
            case .created:
                break
            case .saved(var saved):
                saved.saveId = saveId
                available.state = .saved(saved)
                self = .available(available)
            }
        case .unavailable(var unavailable):
            switch unavailable.state {
            case .aborted:
                break
            case .removed(var removed):
                removed.saveId = saveId
                unavailable.state = .removed(removed)
                self = .unavailable(unavailable)
            }
        }
    }

    mutating func setStatusToSaving() {
        switch self {
        case .available(var available):
            switch available.state {
            case .created(var created):
                created.updating = .saving
                available.state = .created(created)
                self = .available(available)
            case .saved(var saved):
                saved.updating = .saving
                available.state = .saved(saved)
                self = .available(available)
            }
        case .unavailable(var unavailable):
            switch unavailable.state {
            case .aborted(var aborted):
                aborted.updating = .saving
                unavailable.state = .aborted(aborted)
                self = .unavailable(unavailable)
            case .removed(var removed):
                removed.updating = .saving
                unavailable.state = .removed(removed)
                self = .unavailable(unavailable)
            }
        }
    }
}

extension RawSyncedObjectData {
    var isAvailable: Bool {
        switch self {
        case .available:
            true
        case .unavailable:
            false
        }
    }

    var saveId: Int64? {
        switch self {
        case .available(let available):
            switch available.state {
            case .created:
                nil
            case .saved(let saved):
                saved.saveId
            }
        case .unavailable(let unavailable):
            switch unavailable.state {
            case .aborted:
                nil
            case .removed(let removed):
                removed.saveId
            }
        }
    }

    var action: ObjectAction {
        switch self {
        case .available(let available):
            switch available.state {
            case .created:
                .insert
            case .saved(let saved):
                switch saved.state {
                case .inserted:
                    .insert
                case .updated:
                    .update
                }
            }
        case .unavailable:
            .remove
        }
    }

    var attributes: [Attribute.Name: SQLValue] {
        get {
            switch self {
            case .available(let available):
                available.attributes
            case .unavailable:
                [:]
            }
        }
        set {
            switch self {
            case var .available(available):
                available.attributes = newValue
                self = .available(available)
            case .unavailable:
                assertionFailure()
            }
        }
    }

    var relationIds: [Relation.Name: [ObjectId]] {
        get {
            switch self {
            case .available(let available):
                available.relationIds
            case .unavailable:
                [:]
            }
        }
        set {
            switch self {
            case var .available(available):
                available.relationIds = newValue
                self = .available(available)
            case .unavailable:
                assertionFailure()
            }
        }
    }
}

extension RawSyncedObjectData? {
    var status: SyncedObject.Status {
        switch self {
        case .some(let rawData):
            switch rawData {
            case .available(let available):
                switch available.state {
                case .created(let created):
                    switch created.updating {
                    case .created:
                        .created
                    case .saving:
                        .saving
                    case .changed:
                        .changed
                    }
                case .saved(let saved):
                    switch saved.updating {
                    case .saved:
                        .saved
                    case .changed:
                        .changed
                    case .saving:
                        .saving
                    }
                }
            case .unavailable(let unavailable):
                switch unavailable.state {
                case .aborted(let aborted):
                    switch aborted.updating {
                    case .aborted:
                        .created
                    case .changed:
                        .changed
                    case .saving:
                        .saving
                    }
                case .removed(let removed):
                    switch removed.updating {
                    case .saved:
                        .saved
                    case .changed:
                        .changed
                    case .saving:
                        .saving
                    }
                }
            }
        case .none:
            .cleared
        }
    }
}
