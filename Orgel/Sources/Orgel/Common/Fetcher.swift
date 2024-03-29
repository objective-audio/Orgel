import Combine

public final class Fetcher<Value>: Publisher {
    public typealias Output = Value
    public typealias Failure = Never

    class EventSubscription<S: Subscriber>: Subscription where S.Input == Value {
        private var subscriber: S?
        private weak var fetcher: Fetcher<Value>?
        private var cancellable: AnyCancellable?

        init(subscriber: S, fetcher: Fetcher<Value>) {
            self.subscriber = subscriber
            self.fetcher = fetcher

            cancellable = fetcher.pushSubject.sink { [weak self] value in
                self?.send(value: value)
            }
        }

        func request(_ demand: Subscribers.Demand) {
            guard demand > 0 else { return }

            if let value = fetcher?.fetchHandler() {
                send(value: value)
            }
        }

        func cancel() {
            subscriber = nil
            fetcher = nil
        }

        private func send(value: Value) {
            let _ = subscriber?.receive(value)
        }
    }

    private let fetchHandler: () -> Value?
    private let pushSubject: PassthroughSubject<Value, Never> = .init()

    public init(_ handler: @escaping () -> Value?) {
        self.fetchHandler = handler
    }

    public func receive<S>(subscriber: S)
    where S: Subscriber, Never == S.Failure, Value == S.Input {
        subscriber.receive(subscription: EventSubscription(subscriber: subscriber, fetcher: self))
    }

    public func sendFetchedValue() {
        if let value = fetchHandler() {
            pushSubject.send(value)
        }
    }

    public func send(_ value: Value) {
        pushSubject.send(value)
    }
}
