import Foundation
import Orgel

final class ObjectSelectionPresenter: PresenterForObjectSelectionView {
    private weak var sourceObject: SyncedObject?
    private let relationName: Relation.Name
    private let targetEntityName: Entity.Name
    private weak var interactor: Interactor?
    private weak var navigationLifecycle: RootNavigationLifecycle?

    init?(id: ObjectId) {
        guard
            let lifetime = Lifetime.objectSelection(id: id),
            let navigationLifetime = Lifetime.rootNavigation,
            let sourceObject = navigationLifetime.interactor.object(
                entityName: lifetime.sourceEntityName, id: lifetime.sourceId),
            let targetEntityName = sourceObject.entity.relations[lifetime.relationName]?.target
        else {
            return nil
        }

        self.sourceObject = sourceObject
        self.relationName = lifetime.relationName
        self.targetEntityName = targetEntityName
        self.interactor = navigationLifetime.interactor
        self.navigationLifecycle = navigationLifetime.lifecycle
    }

    var objectsCount: Int {
        interactor?.objectCount(entityName: targetEntityName) ?? 0
    }

    func name(at index: Int) -> String {
        targetObject(at: index)?.attributeValue(forName: .name).textValue ?? "nil"
    }

    func select(at index: Int) {
        guard let targetObject = targetObject(at: index) else { return }
        sourceObject?.addRelationObject(targetObject, forName: relationName)
        navigationLifecycle?.hideObjectSelection()
    }

    private func targetObject(at index: Int) -> SyncedObject? {
        interactor?.object(entityName: targetEntityName, at: index)
    }
}
