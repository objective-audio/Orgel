import Orgel
import SwiftUI

struct RelationView: View {
    let presenter: RelationPresenter

    var body: some View {
        List {
            Section(Localized.RelationView.Section.control) {
                Button(
                    action: {
                        presenter.add()
                    },
                    label: {
                        TextNavigationCell(text: Localized.RelationView.ControlRow.add)
                    }
                )
                .foregroundColor(.primary)
            }
            Section(Localized.RelationView.Section.objects) {
                ForEach(presenter.relationIds, id: \.self) { relationId in
                    if let object = presenter.object(forRelationId: relationId) {
                        RelationObjectCell(presenter: .init(object: object))
                    } else {
                        Text(verbatim: "-")
                    }
                }
                .onDelete { indexSet in
                    presenter.deleteObjects(indexSet: indexSet)
                }
            }
        }
        .navigationTitle(presenter.navigationTitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
    }
}
/*
#Preview {
    RelationView(presenter: .init())
}
*/
