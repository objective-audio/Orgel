import Combine
import Foundation
import Orgel

@MainActor @Observable
final class RelationObjectPresenter {
    private(set) var text: String = ""

    @ObservationIgnored
    private weak var object: SyncedObject?
    @ObservationIgnored
    private(set) var cancellable: AnyCancellable!

    init(text: String) {
        self.text = text
    }

    init(object: SyncedObject) {
        self.object = object

        cancellable = object.publisher.sink { [weak self] event in
            self?.updateText()
        }
    }

    private func updateText() {
        guard let object else {
            text = "-"
            return
        }

        text = "objectId : " + object.id.description
    }
}
