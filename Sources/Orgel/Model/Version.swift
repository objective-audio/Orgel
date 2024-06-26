import Foundation

public struct Version: Sendable {
    public let numbers: [Int]

    public init(_ numbers: [Int]) throws {
        enum InitError: Error {
            case emptyNumbers
        }

        self.numbers = numbers

        if numbers.isEmpty {
            throw InitError.emptyNumbers
        }
    }

    public init(_ string: String) throws {
        enum InitError: Error {
            case invalidStringFormat
        }

        let numbers = try string.components(separatedBy: ".").map {
            if let value = Int($0), value >= 0 {
                return value
            } else {
                throw InitError.invalidStringFormat
            }
        }

        try self.init(numbers)
    }

    public var stringValue: String {
        numbers.map { String($0) }.joined(separator: ".")
    }

    public func compare(_ rhs: Version) -> ComparisonResult {
        let lhsCount = numbers.count
        let rhsCount = rhs.numbers.count
        let count = max(lhsCount, rhsCount)
        for index in 0..<count {
            let lhsValue = index < lhsCount ? numbers[index] : 0
            let rhsValue = index < rhsCount ? rhs.numbers[index] : 0

            if lhsValue < rhsValue {
                return .orderedAscending
            } else if lhsValue > rhsValue {
                return .orderedDescending
            }
        }

        return .orderedSame
    }
}

extension Version: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.compare(rhs) == .orderedSame
    }
}

extension Version: Comparable {
    public static func < (lhs: Version, rhs: Version) -> Bool {
        lhs.compare(rhs) == .orderedAscending
    }
}
