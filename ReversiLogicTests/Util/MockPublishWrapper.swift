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
        self.projectedValue = Response { relay.accept($0) }
    }
}

extension MockPublishWrapper {

    final class Response {
        fileprivate(set) var calledCount = 0
        let accept: (Element) -> Void

        init(accept: @escaping (Element) -> Void) {
            self.accept = accept
        }

        func clear() {
            calledCount = 0
        }
    }
}
