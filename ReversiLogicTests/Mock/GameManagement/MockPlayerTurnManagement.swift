import RxSwift
@testable import ReversiLogic

final class MockPlayerTurnManagement: PlayerTurnManagementProtocol {

    @MockPublishResponse<Void, (Disk, Coordinate)>
    var _callAsFunction: AnyObserver<(Disk, Coordinate)>

    func callAsFunction<A1, A2>(
        waitForPlayer: Observable<Void>,
        setPlayerForDiskWithIndex: Observable<(Disk, Int)>,
        handleSelectedCoordinate: Observable<Coordinate>,
        save: A1,
        willTurnDiskOfComputer: A2,
        didTurnDiskOfComputer: A2
    ) -> Observable<(Disk, Coordinate)> where A1: Acceptable, A2: Acceptable, A1.Element == Void, A2.Element == Disk {
        __callAsFunction.respond().asObservable()
    }
}
