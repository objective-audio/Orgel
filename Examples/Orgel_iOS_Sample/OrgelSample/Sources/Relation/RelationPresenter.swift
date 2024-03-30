import Combine
import Foundation
import Orgel

@MainActor @Observable
final class RelationPresenter {
    private let relationName: Relation.Name
    private weak var object: SyncedObject?
    private weak var interactor: Interactor?
    private weak var navigationLifecycle: RootNavigationLifecycle?

    var navigationTitle: String { relationName.description }

    private var cancellables: Set<AnyCancellable> = []

    init?(id: ObjectId) {
        guard
            let lifetime = Lifetime.relation(id: id),
            let navigationLifetime = Lifetime.rootNavigation,
            let object = navigationLifetime.interactor.object(
                entityName: lifetime.sourceEntityName, id: lifetime.sourceId)
        else {
            return nil
        }

        self.relationName = lifetime.relationName
        self.object = object
        self.interactor = navigationLifetime.interactor
        self.navigationLifecycle = navigationLifetime.lifecycle

        object.publisher.sink { [weak self] _ in
            self?.withMutation(keyPath: \.relationIds) {}
        }.store(in: &cancellables)
    }

    func add() {
        guard let object else { return }
        navigationLifecycle?.showObjectSelection(
            sourceId: object.id, entityName: object.entity.name, relationName: relationName)
    }

    var relationIds: [ObjectId] {
        access(keyPath: \.relationIds)
        return object?.relationIds(forName: relationName) ?? []
    }

    func object(forRelationId id: ObjectId) -> SyncedObject? {
        guard let object, let index = relationIds.firstIndex(of: id) else { return nil }
        return interactor?.relationObject(
            sourceObject: object, relationName: relationName, at: index)
    }

    func deleteObjects(indexSet: IndexSet) {
        object?.removeRelations(forName: relationName, indexSet: indexSet)
    }
}
