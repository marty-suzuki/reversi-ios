import RxRelay

@propertyWrapper
final class TestObserver<Element> {
    fileprivate let relay = PublishRelay<Result<Element, Error>>()

    func success(_ value: Element) {
        relay.accept(.success(value))
    }

    func failure(_ error: Error) {
        relay.accept(.failure(error))
    }
}
