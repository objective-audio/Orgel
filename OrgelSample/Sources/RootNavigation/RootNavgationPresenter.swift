import Combine
import Foundation
import Orgel

enum RootNavigationContent: Hashable {
    case object(id: ObjectId)
    case relation(id: ObjectId)
    case objectSelection(id: ObjectId)
}

final class RootNavgationPresenter: PresenterForRootNavigationView {
    private weak var lifecycle: RootNavigationLifecycle?

    var contents: [RootNavigationContent] {
        get {
            lifecycle?.currents.map {
                switch $0 {
                case let .object(lifetime):
                    .object(id: lifetime.id)
                case let .relation(lifetime):
                    .relation(id: lifetime.sourceId)
                case let .objectSelection(lifetime):
                    .objectSelection(id: lifetime.sourceId)
                }
            } ?? []
        }
        set { lifecycle?.setCurrentsCount(newValue.count) }
    }

    private var cancellables: Set<AnyCancellable> = []

    init(lifecycle: RootNavigationLifecycle) {
        self.lifecycle = lifecycle

        lifecycle.currentsPublisher.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
    }

    convenience init?() {
        guard let lifetime = Lifetime.rootNavigation else {
            return nil
        }

        self.init(lifecycle: lifetime.lifecycle)
    }
}
