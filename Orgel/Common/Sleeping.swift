import Foundation

protocol Sleeping: Sendable {
    func sleep() async throws
}
