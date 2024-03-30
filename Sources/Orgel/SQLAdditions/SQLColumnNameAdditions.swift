import Foundation

extension SQLColumn.Name {
    static let version: SQLColumn.Name = .init("version")
    static let currentSaveId: SQLColumn.Name = .init("cur_save_id")
    static let lastSaveId: SQLColumn.Name = .init("last_save_id")
    static let pkId: SQLColumn.Name = .init("pk_id")
    static let saveId: SQLColumn.Name = .init("save_id")
    static let rowid: SQLColumn.Name = .init("rowid")
    static let objectId: SQLColumn.Name = .init("obj_id")
    static let action: SQLColumn.Name = .init("action")
    static let sourcePkId: SQLColumn.Name = .init("src_pk_id")
    static let sourceObjectId: SQLColumn.Name = .init("src_obj_id")
    static let targetObjectId: SQLColumn.Name = .init("tgt_obj_id")
}
