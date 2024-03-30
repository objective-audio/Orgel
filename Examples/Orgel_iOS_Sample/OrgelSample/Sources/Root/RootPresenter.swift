import Combine
import Foundation

@MainActor @Observable
final class RootPresenter {
    enum Content {
        case loading
        case failed(Error)
        case navigation
    }

    private(set) var content: Content = .loading

    @ObservationIgnored
    private var cancellables: Set<AnyCancellable> = []

    init(content: Content) {
        self.content = content
    }

    init(lifecycle: RootLifecycle) {
        lifecycle.currentPublisher.sink { [weak self] lifetime in
            self?.content = lifetime?.content ?? .loading
        }.store(in: &cancellables)
    }
}

extension RootLifecycle.SubLifetime {
    fileprivate var content: RootPresenter.Content {
        switch self {
        case .loading:
            .loading
        case let .failure(error):
            .failed(error)
        case .navigation:
            .navigation
        }
    }
}
