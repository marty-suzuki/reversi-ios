import RxRelay
import RxSwift

final class Watcher<Element> {

    var calledCount: Int { _calledCount.value }
    var parameters: [Element] { _parameters.value }

    private let _calledCount = BehaviorRelay<Int>(value: 0)
    private let _parameters = BehaviorRelay<[Element]>(value: [])
    private let disposeBag = DisposeBag()

    init<T: ObservableType>(_ observable: T) where T.Element == Element {
        observable
            .withLatestFrom(_parameters) { $1 + [$0] }
            .bind(to: _parameters)
            .disposed(by: disposeBag)

        observable
            .withLatestFrom(_calledCount) { $1 + 1 }
            .bind(to: _calledCount)
            .disposed(by: disposeBag)
    }
}
