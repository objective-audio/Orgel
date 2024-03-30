import SwiftUI

struct RelationObjectCell: View {
    let presenter: RelationObjectPresenter

    var body: some View {
        Text(verbatim: presenter.text)
    }
}

#Preview {
    List {
        RelationObjectCell(presenter: .init(text: "test text"))
    }
}
