import Combine
import Foundation
import Orgel

@MainActor
final class RootLifecycle {
    static var shared: RootLifecycle = .init()

    enum SubLifetime {
        case loading(RootLoadingLifetime)
        case failure(Error)
        case navigation(RootNavigationLifetime)
    }

    private let currentSubject: CurrentValueSubject<SubLifetime?, Never> = .init(nil)
    var current: SubLifetime? { currentSubject.value }
    var currentPublisher: AnyPublisher<SubLifetime?, Never> {
        currentSubject.eraseToAnyPublisher()
    }

    init() {
        switchToLoading()
    }

    func switchToLoading() {
        guard current == nil else {
            assertionFailure()
            return
        }

        let loader = RootLoader(rootLifecycle: self)
        currentSubject.value = .loading(.init(loader: loader))
        loader.load()
    }

    func switchToFailure(error: Error) {
        guard case .loading = current else {
            assertionFailure()
            return
        }

        currentSubject.value = .failure(error)
    }

    func switchToNavigation(container: OrgelContainer) {
        guard case .loading = current else {
            assertionFailure()
            return
        }

        currentSubject.value = .navigation(
            .init(interactor: .init(databaseContainer: container), lifecycle: .init()))
    }
}
