import RxSwift

@propertyWrapper
final class MockPublishResponse<Parameter, Element> {
    var wrappedValue: AnyObserver<Element> {
        subject.asObserver()
    }

    let projectedValue = State()
    private let subject = PublishSubject<Element>()

    func respond(_ parameter: Parameter) ->  Observable<Element> {
        projectedValue.calledCount += 1
        projectedValue.parameters += [parameter]
        return subject
    }
}

extension MockPublishResponse {

    final class State {
        fileprivate(set) var calledCount = 0
        fileprivate(set) var parameters: [Parameter] = []

        func clear() {
            calledCount = 0
            parameters = []
        }
    }
}

extension MockPublishResponse where Parameter == Void {

    func respond() -> Observable<Element> {
        self.respond(())
    }
}
