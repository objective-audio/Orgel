import Foundation
import Orgel

@MainActor @Observable
final class ObjectAttributeCellContent {
    let name: Attribute.Name

    var valueText: String {
        get {
            access(keyPath: \.valueText)
            return object?.attributeValue(forName: name).editingStringValue ?? ""
        }
        set {
            withMutation(keyPath: \.valueText) {
                object?.setAttributeEditingStringValue(newValue, forName: name)
            }
        }
    }

    @ObservationIgnored
    private weak var object: SyncedObject?

    init(name: Attribute.Name, object: SyncedObject? = nil) {
        self.name = name
        self.object = object
    }
}
