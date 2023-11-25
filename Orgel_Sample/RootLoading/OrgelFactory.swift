import Foundation
import Orgel

final class OrgelFactory: Sendable {
    enum MakeError: Error {
        case documentDirectoryNotFound
        case makeContainerFailed(Error)
    }

    func makeOrgelContainer() async throws -> OrgelContainer {
        let model = SampleModel.make()

        guard
            let documentUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                .first
        else {
            throw MakeError.documentDirectoryNotFound
        }

        let url = documentUrl.appendingPathComponent("db.sqlite")

        let container: OrgelContainer

        do {
            container = try await OrgelContainer.makeWithSetup(
                url: url, model: model)
        } catch {
            throw MakeError.makeContainerFailed(error)
        }

        return container
    }
}
