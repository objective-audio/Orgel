import Foundation

@MainActor
final class RootLoader {
    private weak var rootLifecycle: RootLifecycle?

    init(rootLifecycle: RootLifecycle) {
        self.rootLifecycle = rootLifecycle
    }

    func load() {
        Task {
            let factory = OrgelFactory()

            do {
                let container = try await factory.makeOrgelContainer()
                rootLifecycle?.switchToNavigation(container: container)
            } catch {
                rootLifecycle?.switchToFailure(error: error)
            }
        }
    }
}
