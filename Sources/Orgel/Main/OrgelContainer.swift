import Combine
import Foundation

public final class OrgelContainer: Sendable {
    public let executor: OrgelExecutor
    public let model: Model
    public let data: OrgelData

    init(executor: OrgelExecutor, model: Model, data: OrgelData) {
        self.executor = executor
        self.model = model
        self.data = data
    }

    public static func makeWithSetup(url: URL, model: Model) async throws -> OrgelContainer {
        let sqliteExecutor = SQLiteExecutor(url: url)
        let info = try await sqliteExecutor.setup(model: model)
        let data = await OrgelData(info: info, model: model)
        let executor = OrgelExecutor(model: model, data: data, sqliteExecutor: sqliteExecutor)
        return .init(executor: executor, model: model, data: data)
    }
}
