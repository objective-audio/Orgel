import SwiftUI

@MainActor
protocol PresenterForObjectSelectionView {
    var objectsCount: Int { get }
    func name(at index: Int) -> String
    func select(at index: Int)
}

struct ObjectSelectionView<Presenter: PresenterForObjectSelectionView>: View {
    let presenter: Presenter

    var body: some View {
        List {
            if presenter.objectsCount > 0 {
                ForEach(0..<presenter.objectsCount, id: \.self) { index in
                    Button(
                        action: {
                            presenter.select(at: index)
                        },
                        label: {
                            Text(
                                Localized.ObjectSelectionView.objectCell(
                                    presenter.name(at: index)))
                        }
                    )
                    .foregroundColor(.primary)
                }
            } else {
                Text(Localized.ObjectSelectionView.empty)
            }
        }
    }
}

// MARK: - Preview

private final class PreviewPresenter: PresenterForObjectSelectionView {
    private let contents: [String] = ["first text", "second text"]
    var objectsCount: Int { contents.count }

    func name(at index: Int) -> String {
        contents[index]
    }

    func select(at index: Int) {}
}

#Preview {
    ObjectSelectionView(presenter: PreviewPresenter())
}
