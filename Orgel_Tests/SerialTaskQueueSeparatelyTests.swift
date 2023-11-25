import XCTest

@testable import Orgel

final class DatabaseQueueSeparatelyTests: XCTestCase {
    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
    }

    func testExecuteSeparately() async throws {
        let queue = SerialTaskQueue()

        let id1 = await queue.addTask()
        let id2 = await queue.addTask()

        // 前のアクションの実行前は実行できない
        await AssertThrowsErrorAsync(try await queue.executeTaskIfNeeded(id: id2).get())

        // 先頭のアクションは実行できる
        try await queue.executeTaskIfNeeded(id: id1).get()

        // 実行中に重複して実行はできない
        await AssertThrowsErrorAsync(try await queue.executeTaskIfNeeded(id: id1).get())

        // 前のアクションの実行中は実行できない
        await AssertThrowsErrorAsync(try await queue.executeTaskIfNeeded(id: id2).get())

        // 実行中でなければ完了できない
        await AssertThrowsErrorAsync(try await queue.resume(id: id2).get())

        // 実行中であれば完了できる
        try await queue.resume(id: id1).get()

        // 重複して完了できない
        await AssertThrowsErrorAsync(try await queue.resume(id: id1).get())

        // 先頭のアクションが完了したので次のアクションが実行できる
        try await queue.executeTaskIfNeeded(id: id2).get()

        // 実行中であれば完了できる。queueが空になる
        try await queue.resume(id: id2).get()

        // 空なので新たなアクションを追加して実行できる
        let id3 = await queue.addTask()
        try await queue.executeTaskIfNeeded(id: id3).get()
        try await queue.resume(id: id3).get()
    }
}
