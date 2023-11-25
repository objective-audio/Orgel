import Foundation

extension SQLParameter.Name {
    static let version: SQLParameter.Name = .init("version")
    static let currentSaveId: SQLParameter.Name = .init("cur_save_id")
    static let lastSaveId: SQLParameter.Name = .init("last_save_id")
    static let pkId: SQLParameter.Name = .init("pk_id")
    static let saveId: SQLParameter.Name = .init("save_id")
    static let objectId: SQLParameter.Name = .init("obj_id")
    static let action: SQLParameter.Name = .init("action")
    static let sourcePkId: SQLParameter.Name = .init("src_pk_id")
    static let sourceObjectId: SQLParameter.Name = .init("src_obj_id")
    static let targetObjectId: SQLParameter.Name = .init("tgt_obj_id")
}
