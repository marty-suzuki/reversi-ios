import RxRelay
import RxSwift

public struct ValueObservable<Element>: ObservableType {

    public var value: Element {
        relay.value
    }

    private let relay: BehaviorRelay<Element>

    init(relay: BehaviorRelay<Element>) {
        self.relay = relay
    }

    public func subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Element == Observer.Element {
        relay.subscribe(observer)
    }

    public func asObservable() -> Observable<Element> {
        relay.asObservable()
    }
}
