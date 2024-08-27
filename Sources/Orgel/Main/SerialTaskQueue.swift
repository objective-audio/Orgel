import Foundation

actor SerialTaskQueue {
    private var lastTask: Task<(), any Error>?

    func execute<Result: Sendable>(
        _ handler: @Sendable @escaping () async throws -> Result
    ) async throws -> Result {
        let lastTask = self.lastTask

        let task = Task {
            let _ = try await lastTask?.value
            return try await handler()
        }

        self.lastTask = Task {
            let _ = try await task.value
        }

        return try await task.value
    }
}
