import RxSwift
@testable import ReversiLogic

final class MockAlertManagement: AlertManagementProtocol {

    @MockPublishResponse<Void, Alert>
    var _callAsFunction: AnyObserver<Alert>

    func callAsFunction<A>(
        nextTurnResponse: Observable<NextTurn.Response>,
        prepareForReset: Observable<Void>,
        nextTurn: A,
        reset: A,
        waitForPlayer: A
    ) -> Observable<Alert> where A: Acceptable, A.Element == Void {
        __callAsFunction.respond().asObservable()
    }
}
