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
        self.projectedValue = Response(relay: relay)
    }
}

extension MockBehaviorWrapeer {

    final class Response {
        fileprivate(set) var calledCount = 0
        fileprivate(set) var parameters: [Element] = []
        private let relay: BehaviorRelay<Element>

        init(relay: BehaviorRelay<Element>) {
            self.relay = relay
        }

        func accept(_ value: Element) {
            parameters += [value]
            relay.accept(value)
        }

        func clear() {
            calledCount = 0
        }
    }
}
