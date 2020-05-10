import RxSwift
@testable import ReversiLogic

final class MockNextTurnManagement: NextTurnManagementProtocol {

    @MockPublishResponse<Void, NextTurn.Response>
    var _callAsFunction: AnyObserver<NextTurn.Response>

    func callAsFunction(nextTurn: Observable<Void>) -> Observable<NextTurn.Response> {
        __callAsFunction.respond().asObservable()
    }
}
