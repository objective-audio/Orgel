import Foundation
import Orgel

enum Localized {
    enum Common {
        enum Alert {
            static var ok: String {
                .init(
                    localized: "common.alert.ok", defaultValue: "OK"
                )
            }
        }
    }
    enum RootFailureView {
        static var databaseSetupFailedTitle: String {
            .init(
                localized: "rootFailure.databaseSetupFailed", defaultValue: "Database setup failed."
            )
        }
    }
    enum ObjectView {
        enum Section {
            static func objectId(_ objectId: String) -> String {
                return .init(
                    localized: "object.section.objectId",
                    defaultValue: "Object Id : \(objectId)")
            }
            static var attributes: String {
                .init(localized: "object.section.attributes", defaultValue: "Attributes")
            }
            static var relations: String {
                .init(localized: "object.section.relations", defaultValue: "Relations")
            }
        }
    }
    enum TopView {
        enum Section {
            static var actions: String {
                .init(localized: "top.section.actions", defaultValue: "Actions")
            }
            static var info: String {
                .init(localized: "top.section.info", defaultValue: "Info")
            }
            static var objectsA: String {
                .init(localized: "top.section.objectsA", defaultValue: "Objects A")
            }
            static var objectsB: String {
                .init(localized: "top.section.objectsB", defaultValue: "Objects B")
            }
        }
        enum ActionRow {
            static var createA: String {
                .init(localized: "top.actionRow.createA", defaultValue: "Create A")
            }
            static var createB: String {
                .init(localized: "top.actionRow.createB", defaultValue: "Create B")
            }
            static var insertA: String {
                .init(localized: "top.actionRow.insertA", defaultValue: "Insert A")
            }
            static var insertB: String {
                .init(localized: "top.actionRow.insertB", defaultValue: "Insert B")
            }
            static var undo: String {
                .init(localized: "top.actionRow.undo", defaultValue: "Undo")
            }
            static var redo: String {
                .init(localized: "top.actionRow.redo", defaultValue: "Redo")
            }
            static var clear: String {
                .init(localized: "top.actionRow.clear", defaultValue: "Clear")
            }
            static var purge: String {
                .init(localized: "top.actionRow.purge", defaultValue: "Purge")
            }
            static var saveChanged: String {
                .init(localized: "top.actionRow.saveChanged", defaultValue: "Save Changed")
            }
            static var cancelChanged: String {
                .init(localized: "top.actionRow.cancelChanged", defaultValue: "Cancel Changed")
            }
        }
        enum InfoRow {
            static func saveId(current: Int64, last: Int64) -> String {
                .init(
                    localized: "top.infoRow.saveId",
                    defaultValue: "Current Save ID: \(current) / Last Save ID: \(last)")
            }
            static func objectCount(a: Int, b: Int) -> String {
                .init(
                    localized: "top.infoRow.objectCount", defaultValue: "Object Count A:\(a) B:\(b)"
                )
            }
        }
        enum Alert {
            static var title: String {
                .init(localized: "top.alert.title", defaultValue: "Operation Failed")
            }
        }
    }
    enum RelationView {
        enum Section {
            static var control: String {
                .init(localized: "relation.section.control", defaultValue: "Control")
            }
            static var objects: String {
                .init(localized: "relation.section.objects", defaultValue: "Objects")
            }
        }
        enum ControlRow {
            static var add: String {
                .init(localized: "relation.controlRow.add", defaultValue: "Add")
            }
        }
    }
    enum ObjectSelectionView {
        static func objectCell(_ name: String) -> String {
            .init(localized: "objectSelectionView.objectCell", defaultValue: "name : \(name)")
        }
        static var empty: String {
            .init(localized: "objectSelectionView.empty", defaultValue: "Empty")
        }
    }
}
