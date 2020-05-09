import RxRelay
import RxSwift

final class Watcher<Element> {

    var calledCount: Int { _calledCount.value }
    var parameters: [Element] { _parameters.value }
    var errors: [Error] { _errors.value }

    private let _calledCount = BehaviorRelay<Int>(value: 0)
    private let _parameters = BehaviorRelay<[Element]>(value: [])
    private let _errors = BehaviorRelay<[Error]>(value: [])
    private let disposeBag = DisposeBag()

    init<T: ObservableType>(_ observable: T) where T.Element == Element {
        /// If an event emitted immediately and using `.share()`, that event is not shared to second and subsequent subscriptions by a specification for RxSwift.
        /// - seealso: https://qiita.com/marty-suzuki/items/53431d30bfc99fe74352
        let relay = PublishRelay<Result<Element, Error>>()

        relay
            .flatMap { result -> Observable<Element> in
                switch result {
                case let .success(value):
                    return .just(value)
                case .failure:
                    return .empty()
                }
            }
            .withLatestFrom(_parameters) { $1 + [$0] }
            .bind(to: _parameters)
            .disposed(by: disposeBag)

        relay
            .flatMap { result -> Observable<Error> in
                switch result {
                case let .failure(error):
                    return .just(error)
                case .success:
                    return .empty()
                }
            }
            .withLatestFrom(_errors) { $1 + [$0] }
            .bind(to: _errors)
            .disposed(by: disposeBag)

        relay
            .map { _ in }
            .catchErrorJustReturn(())
            .withLatestFrom(_calledCount) { $1 + 1 }
            .bind(to: _calledCount)
            .disposed(by: disposeBag)

        observable
            .map(Result.success)
            .catchError { .just(.failure($0)) }
            .bind(to: relay)
            .disposed(by: disposeBag)

    }

    func clear() {
        _calledCount.accept(0)
        _parameters.accept([])
    }
}
