import Foundation
import Orgel

final class ObjectPresenter: PresenterForObjectView {
    private weak var object: SyncedObject?
    private weak var navigationLifecycle: RootNavigationLifecycle?
    let attributeContents: [ObjectAttributeCellContent]

    var objectIdText: String { object?.id.description ?? "nil" }
    var modelRelations: [Relation] {
        object?.modelRelations ?? []
    }

    init?(id: ObjectId) {
        guard
            let lifetime = Lifetime.object(id: id),
            let navigationLifetime = Lifetime.rootNavigation,
            let object = navigationLifetime.interactor.object(
                entityName: lifetime.entityName, id: lifetime.id)
        else {
            return nil
        }

        self.object = object
        self.navigationLifecycle = navigationLifetime.lifecycle
        self.attributeContents = object.modelCustomAttributes.map {
            ObjectAttributeCellContent(name: $0.name, object: object)
        }
    }

    func showRelation(name: Relation.Name) {
        guard let object else { return }
        navigationLifecycle?.showRelation(
            sourceId: object.id, sourceEntityName: object.entity.name, relationName: name)
    }
}
