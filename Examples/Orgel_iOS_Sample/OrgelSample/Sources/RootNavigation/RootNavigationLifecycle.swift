import Combine
import Foundation
import Orgel

@MainActor
final class RootNavigationLifecycle {
    enum SubLifetime {
        case object(ObjectLifetime)
        case relation(RelationLifetime)
        case objectSelection(ObjectSelectionLifetime)
    }

    private let currentsSubject: CurrentValueSubject<[SubLifetime], Never> = .init([])
    var currents: [SubLifetime] { currentsSubject.value }
    var currentsPublisher: AnyPublisher<[SubLifetime], Never> {
        currentsSubject.eraseToAnyPublisher()
    }

    func showObject(id: ObjectId, entityName: Entity.Name) {
        guard currents.isEmpty else {
            assertionFailure()
            return
        }

        currentsSubject.value.append(.object(.init(id: id, entityName: entityName)))
    }

    func showRelation(
        sourceId: ObjectId, sourceEntityName: Entity.Name, relationName: Relation.Name
    ) {
        guard currents.count == 1, case .object = currents[0] else {
            assertionFailure()
            return
        }

        currentsSubject.value.append(
            .relation(
                .init(
                    sourceId: sourceId, sourceEntityName: sourceEntityName,
                    relationName: relationName)
            ))
    }

    func showObjectSelection(
        sourceId: ObjectId, entityName: Entity.Name, relationName: Relation.Name
    ) {
        guard currents.count == 2, case .object = currents[0],
            case .relation = currents[1]
        else {
            assertionFailure()
            return
        }

        currentsSubject.value.append(
            .objectSelection(
                .init(sourceId: sourceId, sourceEntityName: entityName, relationName: relationName))
        )
    }

    func hideObjectSelection() {
        guard currents.count == 3, case .object = currents[0],
            case .relation = currents[1],
            case .objectSelection = currents[2]
        else {
            assertionFailure()
            return
        }

        currentsSubject.value.removeLast()
    }

    func setCurrentsCount(_ count: Int) {
        guard count < currentsSubject.value.count else {
            return
        }

        currentsSubject.value = Array(currents.prefix(count))
    }
}
