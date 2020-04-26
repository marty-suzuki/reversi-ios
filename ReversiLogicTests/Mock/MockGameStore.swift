import RxSwift
import RxTest
@testable import ReversiLogic

final class MockGameStore: GameStoreProtocol {

    @MockBehaviorWrapeer(value: [:])
    var playerCancellers: ValueObservable<[Disk : Canceller]>

    @MockBehaviorWrapeer(value: nil)
    var placeDiskCanceller: ValueObservable<Canceller?>

    @MockBehaviorWrapeer(value: false)
    var isDiskPlacing: ValueObservable<Bool>

    @MockBehaviorWrapeer(value: [])
    var cells: ValueObservable<[[GameData.Cell]]>

    @MockBehaviorWrapeer(value: .turn(.dark))
    var status: ValueObservable<GameData.Status>

    @MockBehaviorWrapeer(value: .manual)
    var playerDark: ValueObservable<GameData.Player>

    @MockBehaviorWrapeer(value: .manual)
    var playerLight: ValueObservable<GameData.Player>

    @MockBehaviorWrapeer(value: 0)
    var countOfDark: ValueObservable<Int>

    @MockBehaviorWrapeer(value: 0)
    var countOfLight: ValueObservable<Int>

    @MockBehaviorWrapeer(value: nil)
    var playerOfCurrentTurn: ValueObservable<GameData.Player?>

    @MockBehaviorWrapeer(value: nil)
    var sideWithMoreDisks: ValueObservable<Disk?>

    @MockPublishWrapper
    var faildToLoad: Observable<Void>

    @MockPublishWrapper
    var loaded: Observable<Void>

    @MockPublishWrapper
    var reset: Observable<Void>

    @MockResponse<Coordinate, Disk?>
    var diskAtCoordinate: Disk? = nil

    func disk(at coordinate: Coordinate) -> Disk? {
        cells.value[safe: coordinate.y]?[safe: coordinate.x]?.disk
        //_diskAtCoordinate.respond(coordinate)
    }
}
