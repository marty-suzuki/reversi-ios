import RxRelay
import RxSwift
@testable import ReversiLogic

@propertyWrapper
final class MockBehaviorWrapeer<Element> {

    var wrappedValue: ValueObservable<Element> {
        projectedValue.calledCount += 1
        return _valueObservable
    }

    let projectedValue: Response

    private let _valueObservable: ValueObservable<Element>

    init(value: Element) {
        let relay = BehaviorRelay<Element>(value: value)
        self._valueObservable = ValueObservable(relay: relay)
        self.projectedValue = Response { relay.accept($0) }
    }
}

extension MockBehaviorWrapeer {

    final class Response {
        fileprivate(set) var calledCount = 0
        let accept: (Element) -> Void
        init(accept: @escaping (Element) -> Void) {
            self.accept = accept
        }
    }
}
