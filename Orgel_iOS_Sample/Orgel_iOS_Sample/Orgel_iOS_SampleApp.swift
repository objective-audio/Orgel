import SwiftUI

@main
struct Orgel_iOS_SampleApp: App {
    var body: some Scene {
        WindowGroup {
            RootView(presenter: RootPresenter(lifecycle: .shared))
        }
    }
}
