import Orgel
import XCTest

final class FetcherTests: XCTestCase {
    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
    }

    func test() {
        var fetchedValue: Int? = 0

        let fetcher = Fetcher<Int> {
            fetchedValue
        }

        var received: [Int] = []

        let canceller = fetcher.sink { value in
            received.append(value)
        }

        XCTAssertEqual(received.count, 1)

        fetcher.send(1)

        XCTAssertEqual(received.count, 2)
        XCTAssertEqual(received[1], 1)

        fetchedValue = 2
        fetcher.sendFetchedValue()

        XCTAssertEqual(received.count, 3)
        XCTAssertEqual(received[2], 2)

        canceller.cancel()

        fetcher.send(3)

        XCTAssertEqual(received.count, 3)
    }
}
