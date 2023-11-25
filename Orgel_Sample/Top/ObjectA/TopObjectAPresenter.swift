import Combine
import Foundation
import Orgel

@MainActor @Observable
final class TopObjectAPresenter {
    private(set) var text: String = ""
    private(set) var isNavigation: Bool = false

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
            guard let self else { return }
            self.updateText()
            self.isNavigation = self.object?.isAvailable ?? false
        }
    }

    private func updateText() {
        guard let object else {
            text = "-"
            return
        }

        guard let typed = try? object.typed(ObjectA.self) else {
            text = "objectId : " + object.id.description + " \nunavailable"
            return
        }

        let texts: [String] = [
            "objectId : " + typed.id.rawId.description,
            "age : " + String(typed.attributes.age),
            "name : " + typed.attributes.name,
            "status : " + "\(object.status)",
            "action : " + (object.action.flatMap { $0.rawValue } ?? "nil"),
        ]
        text = texts.joined(separator: "\n")
    }
}
