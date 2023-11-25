import SwiftUI

@MainActor
protocol PresenterForRootNavigationView: ObservableObject {
    var contents: [RootNavigationContent] { get set }
}

struct RootNavigationView<Presenter: PresenterForRootNavigationView>: View {
    @ObservedObject var presenter: Presenter

    var body: some View {
        NavigationStack(path: $presenter.contents) {
            Group {
                if let presenter = TopPresenter() {
                    TopView(presenter: presenter)
                } else {
                    Text(verbatim: "TopView")
                }
            }
            .navigationDestination(for: RootNavigationContent.self) { content in
                switch content {
                case let .object(id):
                    if let presenter = ObjectPresenter(id: id) {
                        ObjectView(presenter: presenter)
                    } else {
                        Text(verbatim: "ObjectView")
                    }
                case let .relation(id):
                    if let presenter = RelationPresenter(id: id) {
                        RelationView(presenter: presenter)
                    } else {
                        Text(verbatim: "RelationView")
                    }
                case let .objectSelection(id):
                    if let presenter = ObjectSelectionPresenter(id: id) {
                        ObjectSelectionView(presenter: presenter)
                    } else {
                        Text(verbatim: "ObjectSelectionView")
                    }
                }
            }
        }
    }
}

// MARK: - Preview

private final class PreviewPresenter: PresenterForRootNavigationView {
    var contents: [RootNavigationContent] = []
}

#Preview {
    RootNavigationView(presenter: PreviewPresenter())
}
