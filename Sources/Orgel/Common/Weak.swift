import Foundation

class Weak<T: AnyObject> {
    private(set) weak var value: T?

    init(value: T) {
        self.value = value
    }
}
