import Foundation
import Orgel

final class OrgelFactory: Sendable {
    func makeOrgelContainer() async throws -> OrgelContainer {
        enum MakeError: Error {
            case documentDirectoryNotFound
        }

        let model = SampleModel.make()

        guard
            let documentUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                .first
        else {
            throw MakeError.documentDirectoryNotFound
        }

        let url = documentUrl.appendingPathComponent("db.sqlite")

        return try await OrgelContainer.makeWithSetup(url: url, model: model)
    }
}
