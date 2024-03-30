import SwiftUI

struct TopObjectBCell: View {
    let presenter: TopObjectBPresenter
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
        TopObjectBCell(presenter: .init(text: "test text"), action: {})
    }
}
