import RxRelay
import RxSwift
@testable import ReversiLogic

@propertyWrapper
final class MockPublishWrapper<Element> {

    var wrappedValue: Observable<Element> {
        projectedValue.calledCount += 1
        return _observable
    }

    let projectedValue: Response

    private let _observable: Observable<Element>

    init() {
        let relay = PublishRelay<Element>()
        self._observable = relay.asObservable()
        self.projectedValue = Response(relay: relay)
    }
}

extension MockPublishWrapper {

    final class Response {
        fileprivate(set) var calledCount = 0
        fileprivate(set) var parameters: [Element] = []
        private let relay: PublishRelay<Element>

        init(relay: PublishRelay<Element>) {
            self.relay = relay
        }

        func accept(_ value: Element) {
            parameters += [value]
            relay.accept(value)
        }

        func clear() {
            calledCount = 0
            parameters.removeAll()
        }
    }
}
