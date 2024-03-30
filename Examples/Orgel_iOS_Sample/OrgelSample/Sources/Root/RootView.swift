import Combine
import SwiftUI

struct RootView: View {
    let presenter: RootPresenter

    var body: some View {
        switch presenter.content {
        case .loading:
            RootLoadingView()
        case let .failed(error):
            RootFailureView(error: error)
        case .navigation:
            if let presenter = RootNavgationPresenter() {
                RootNavigationView(presenter: presenter)
            } else {
                Text(verbatim: "RootNavigationView")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    RootView(presenter: RootPresenter(content: .loading))
}
