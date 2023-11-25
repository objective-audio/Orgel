import XCTest

@testable import Orgel

final class SerialTaskQueueOrderTests: XCTestCase {
    func testExecute() async throws {
        let queue = SerialTaskQueue()

        let sleeper1 = SleeperMock()
        let sleeper2 = SleeperMock()
        let sleeper3 = SleeperMock()

        let taskId1 = await queue.addTask()
        let taskId2 = await queue.addTask()
        let taskId3 = await queue.addTask()

        async let timeWaiting1 = queue.execute(sleeper: sleeper1, id: taskId1) {
            CFAbsoluteTimeGetCurrent()
        }

        async let timeWaiting2 = queue.execute(sleeper: sleeper2, id: taskId2) {
            CFAbsoluteTimeGetCurrent()
        }

        async let timeWaiting3 = queue.execute(sleeper: sleeper3, id: taskId3) {
            CFAbsoluteTimeGetCurrent()
        }

        await fulfillment(of: [sleeper1.expectation], timeout: 10.0)
        await sleeper1.resume()

        let time1 = try await timeWaiting1

        await fulfillment(of: [sleeper2.expectation], timeout: 10.0)
        await sleeper2.resume()

        let time2 = try await timeWaiting2

        await fulfillment(of: [sleeper3.expectation], timeout: 10.0)
        await sleeper3.resume()

        let time3 = try await timeWaiting3

        XCTAssertTrue(time1 < time2)
        XCTAssertTrue(time2 < time3)
    }
}
