import Combine
import Orgel
import SwiftUI

@MainActor
protocol PresenterForTopView: ObservableObject {
    var currentSaveId: Int64 { get }
    var lastSaveId: Int64 { get }

    var aObjectsCount: Int { get }
    func aObject(at index: Int) -> SyncedObject?
    var bObjectsCount: Int { get }
    func bObject(at index: Int) -> SyncedObject?

    func performAction(_ action: TopAction)
    func isAvailable(forAction action: TopAction) -> Bool

    var isAlertShown: Bool { get set }
    var error: Error? { get }

    func showObject(at index: Int, entityName: Entity.Name)
    func deleteObject(indexSet: IndexSet, entityName: Entity.Name)
}

struct TopView<Presenter: PresenterForTopView>: View {
    @ObservedObject var presenter: Presenter

    var body: some View {
        List {
            Section(Localized.TopView.Section.actions) {
                ForEach(TopAction.allCases, id: \.self) { action in
                    Button(
                        action: {
                            presenter.performAction(action)
                        },
                        label: {
                            Text(action.title)
                        }
                    )
                    .disabled(!presenter.isAvailable(forAction: action))
                }
            }
            Section(Localized.TopView.Section.info) {
                Text(
                    Localized.TopView.InfoRow.saveId(
                        current: presenter.currentSaveId, last: presenter.lastSaveId))
                Text(
                    Localized.TopView.InfoRow.objectCount(
                        a: presenter.aObjectsCount, b: presenter.bObjectsCount))
            }
            Section(Localized.TopView.Section.objectsA) {
                ForEach(0..<presenter.aObjectsCount, id: \.self) { index in
                    if let object = presenter.aObject(at: index) {
                        TopObjectACell(presenter: .init(object: object)) {
                            presenter.showObject(at: index, entityName: .a)
                        }
                        .foregroundColor(.primary)
                        .deleteDisabled(!object.isAvailable)
                    } else {
                        Text(verbatim: "TopObjectACell index:\(index)")
                    }
                }
                .onDelete { indexSet in
                    presenter.deleteObject(indexSet: indexSet, entityName: .a)
                }
            }
            Section(Localized.TopView.Section.objectsB) {
                ForEach(0..<presenter.bObjectsCount, id: \.self) { index in
                    if let object = presenter.bObject(at: index) {
                        TopObjectBCell(presenter: .init(object: object)) {
                            presenter.showObject(at: index, entityName: .b)
                        }
                        .foregroundColor(.primary)
                        .deleteDisabled(!object.isAvailable)
                    } else {
                        Text(verbatim: "TopObjectBCell index:\(index)")
                    }
                }
                .onDelete { indexSet in
                    presenter.deleteObject(indexSet: indexSet, entityName: .b)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .alert(Localized.TopView.Alert.title, isPresented: $presenter.isAlertShown) {
            Button(Localized.Common.Alert.ok) {}
        } message: {
            Text(verbatim: presenter.error?.localizedDescription ?? "")
        }
    }
}

extension TopAction {
    fileprivate var title: String {
        switch self {
        case .createA:
            Localized.TopView.ActionRow.createA
        case .createB:
            Localized.TopView.ActionRow.createB
        case .insertA:
            Localized.TopView.ActionRow.insertA
        case .insertB:
            Localized.TopView.ActionRow.insertB
        case .undo:
            Localized.TopView.ActionRow.undo
        case .redo:
            Localized.TopView.ActionRow.redo
        case .clear:
            Localized.TopView.ActionRow.clear
        case .purge:
            Localized.TopView.ActionRow.purge
        case .saveChanged:
            Localized.TopView.ActionRow.saveChanged
        case .cancelChanged:
            Localized.TopView.ActionRow.cancelChanged
        }
    }
}

// MARK: - Preview

private final class PreviewPresenter: PresenterForTopView {
    let currentSaveId: Int64 = 1
    let lastSaveId: Int64 = 2

    var aObjectsCount: Int { 3 }
    func aObject(at index: Int) -> SyncedObject? { nil }
    var bObjectsCount: Int { 4 }
    func bObject(at index: Int) -> SyncedObject? { nil }

    func performAction(_ action: TopAction) {}
    func isAvailable(forAction action: TopAction) -> Bool {
        true
    }

    var isAlertShown: Bool = false
    let error: Error? = nil

    func showObject(at index: Int, entityName: Entity.Name) {}
    func deleteObject(indexSet: IndexSet, entityName: Entity.Name) {}
}

#Preview {
    return TopView(presenter: PreviewPresenter())
}
