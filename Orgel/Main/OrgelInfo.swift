import Foundation

public struct OrgelInfo: Equatable, Sendable {
    public enum InitError: Error {
        case versionNotFound
        case invalidVersion
        case currentSaveIdNotFound
        case lastSaveIdNotFound
    }

    public let version: Version
    public let currentSaveId: Int64
    public let lastSaveId: Int64

    var nextSaveId: Int64 { currentSaveId + 1 }

    var currentSaveIdValue: SQLValue { .integer(currentSaveId) }
    var lastSaveIdValue: SQLValue { .integer(lastSaveId) }
    var nextSaveIdValue: SQLValue { .integer(nextSaveId) }

    init(version: Version, currentSaveId: Int64, lastSaveId: Int64) {
        self.version = version
        self.currentSaveId = currentSaveId
        self.lastSaveId = lastSaveId
    }

    init(values: [SQLColumn.Name: SQLValue]) throws {
        guard let versionText = values[.version]?.textValue else {
            throw InitError.versionNotFound
        }
        guard let version = try? Version(versionText) else {
            throw InitError.invalidVersion
        }
        guard let currentSaveId = values[.currentSaveId]?.integerValue else {
            throw InitError.currentSaveIdNotFound
        }
        guard let lastSaveId = values[.lastSaveId]?.integerValue else {
            throw InitError.lastSaveIdNotFound
        }
        self = .init(version: version, currentSaveId: currentSaveId, lastSaveId: lastSaveId)
    }

    static let table: SQLTable = .init("db_info")

    static let sqlForCreate: SQLUpdate = .createTable(
        OrgelInfo.table,
        columns: [
            .init(name: .version, valueType: .text),
            .init(name: .currentSaveId, valueType: .integer),
            .init(name: .lastSaveId, valueType: .integer),
        ])

    static let sqlForInsert: SQLUpdate = .insert(
        table: OrgelInfo.table,
        columnNames: [.version, .currentSaveId, .lastSaveId])

    static let sqlForUpdateVersion: SQLUpdate = .update(
        table: OrgelInfo.table, columnNames: [.version])

    static let sqlForUpdateSaveIds: SQLUpdate = .update(
        table: OrgelInfo.table, columnNames: [.currentSaveId, .lastSaveId])

    static let sqlForUpdateCurrentSaveId: SQLUpdate = .update(
        table: OrgelInfo.table, columnNames: [.currentSaveId])
}
