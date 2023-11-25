import Orgel
import SwiftUI

@MainActor
protocol PresenterForObjectView: AnyObject {
    var objectIdText: String { get }
    var attributeContents: [ObjectAttributeCellContent] { get }
    var modelRelations: [Relation] { get }
    func showRelation(name: Relation.Name)
}

struct ObjectView<Presenter: PresenterForObjectView>: View {
    let presenter: Presenter

    var body: some View {
        List {
            Section {
                Text(Localized.ObjectView.Section.objectId(presenter.objectIdText))
            }
            Section(Localized.ObjectView.Section.attributes) {
                // 一つのEntityの中で同じnameは存在しないのでidとして使う
                ForEach(presenter.attributeContents, id: \.name) { attributeContent in
                    ObjectAtrributeCell(content: attributeContent)
                }
            }
            Section(Localized.ObjectView.Section.relations) {
                ForEach(presenter.modelRelations, id: \.name) { relation in
                    ObjectRelationCell(name: relation.name) { name in
                        presenter.showRelation(name: name)
                    }
                }
            }
        }
    }
}

// MARK: - Preview

private final class PreviewContent: PresenterForObjectView {
    let objectIdText: String = "100"
    let modelRelations: [Relation]
    let attributeContents: [ObjectAttributeCellContent]

    init() {
        let model: Model = SampleModel.make()
        attributeContents =
            model.entities[.a]?.customAttributes.map {
                ObjectAttributeCellContent(name: $0.key)
            } ?? []
        modelRelations = model.entities[.a]?.relations.map(\.value) ?? []
    }

    func showRelation(name: Relation.Name) {}
}

#Preview {
    ObjectView(presenter: PreviewContent())
}
