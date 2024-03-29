import Foundation
import Orgel

@MainActor
enum Lifetime {
    static var rootNavigation: RootNavigationLifetime? {
        switch RootLifecycle.shared.current {
        case let .navigation(lifetime):
            lifetime
        default:
            nil
        }
    }

    static func object(id: ObjectId) -> ObjectLifetime? {
        guard case let .object(lifetime) = rootNavigation?.lifecycle.currents.first,
            lifetime.id == id
        else {
            return nil
        }

        return lifetime
    }

    static func relation(id: ObjectId) -> RelationLifetime? {
        guard let navigation = rootNavigation else {
            return nil
        }

        for current in navigation.lifecycle.currents {
            guard case let .relation(lifetime) = current, lifetime.sourceId == id else {
                continue
            }
            return lifetime
        }

        return nil
    }

    static func objectSelection(id: ObjectId) -> ObjectSelectionLifetime? {
        guard let navigation = rootNavigation else {
            return nil
        }

        for current in navigation.lifecycle.currents {
            guard case let .objectSelection(lifetime) = current, lifetime.sourceId == id else {
                continue
            }
            return lifetime
        }

        return nil
    }
}
