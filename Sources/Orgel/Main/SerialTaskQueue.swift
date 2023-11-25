import Foundation

/// OrgelExecutorからSQLiteExecutorで実行される処理の順番を直列にするためのQueue
actor SerialTaskQueue {
    final class TaskId: Sendable {}
    actor Sleeper: Sleeping {
        func sleep() async throws {
            try await Task.sleep(nanoseconds: NSEC_PER_MSEC * 10)
        }
    }

    private var waitingTasks: [TaskId] = []
    private var executingTask: TaskId?

    func addTask() -> TaskId {
        let id = TaskId()
        waitingTasks.append(id)
        return id
    }

    func execute<Result: Sendable>(
        sleeper: some Sleeping = Sleeper(), id: TaskId,
        _ handler: @Sendable () async throws -> Result
    ) async throws -> Result {
        repeat {
            try await sleeper.sleep()
        } while executeTaskIfNeeded(id: id).isFailure

        let result = try await handler()

        try resume(id: id)

        return result
    }
}

// 実際はexecuteしか使わないがテストのために公開しておく
extension SerialTaskQueue {
    enum ResumeError: Error {
        case idNotFound
    }

    func resume(id: TaskId) throws {
        if executingTask == id {
            executingTask = nil
        } else {
            throw ResumeError.idNotFound
        }
    }

    enum ExecuteTaskError: Error {
        case waiting, executing, otherExecuting, idNotFound
    }

    typealias ExecuteTaskResult = Result<Void, ExecuteTaskError>

    func executeTaskIfNeeded(id: TaskId) -> ExecuteTaskResult {
        if let executingTask {
            if executingTask == id {
                return .failure(.executing)
            } else {
                return .failure(.otherExecuting)
            }
        } else if let first = waitingTasks.first, first == id {
            executingTask = first
            waitingTasks.removeFirst()
            return .success(())
        } else if waitingTasks.contains(where: { $0 == id }) {
            return .failure(.waiting)
        } else {
            return .failure(.idNotFound)
        }
    }
}

extension SerialTaskQueue.TaskId: Equatable {
    static func == (lhs: SerialTaskQueue.TaskId, rhs: SerialTaskQueue.TaskId) -> Bool {
        ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
}

extension Result {
    fileprivate var isFailure: Bool {
        switch self {
        case .success:
            return false
        case .failure:
            return true
        }
    }
}
