import RxRelay
import RxSwift

@propertyWrapper
public struct PublishWrapper<Element> {

    public let wrappedValue: Observable<Element>

    private let relay: PublishRelay<Element>

    public init() {
        let relay = PublishRelay<Element>()
        self.relay = relay
        self.wrappedValue = relay.asObservable()
    }

    public func accept(_ value: Element) {
        relay.accept(value)
    }
}

extension PublishWrapper where Element == Void {

    public func accept() {
        accept(())
    }
}

extension ObservableType {

    public func bind(to relay: PublishWrapper<Element>) -> Disposable {
        subscribe { event in
            switch event {
            case let .next(value):
                relay.accept(value)
            case .completed, .error:
                return
            }
        }
    }
}
