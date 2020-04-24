import RxRelay
import RxSwift

@propertyWrapper
public struct BehaviorWrapper<Element> {

    public let wrappedValue: ValueObservable<Element>

    private let relay: BehaviorRelay<Element>

    public init(value: Element) {
        let relay = BehaviorRelay<Element>(value: value)
        self.relay = relay
        self.wrappedValue = ValueObservable(relay: relay)
    }

    public func accept(_ value: Element) {
        relay.accept(value)
    }
}

extension ObservableType {

    public func bind(to relay: BehaviorWrapper<Element>) -> Disposable {
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
