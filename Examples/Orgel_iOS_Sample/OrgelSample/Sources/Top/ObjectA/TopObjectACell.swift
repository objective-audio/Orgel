import SwiftUI

struct TopObjectACell: View {
    let presenter: TopObjectAPresenter
    let action: () -> Void

    var body: some View {
        if presenter.isNavigation {
            Button(action: action) {
                TextNavigationCell(text: presenter.text)
            }
        } else {
            TextCell(text: presenter.text)
        }
    }
}

#Preview {
    List {
        TopObjectACell(presenter: .init(text: "short text"), action: {})
        TopObjectACell(
            presenter: .init(text: "long long long long long long long long text"), action: {})
    }
}
