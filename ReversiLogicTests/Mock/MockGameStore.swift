import RxSwift
import RxTest
@testable import ReversiLogic

final class MockGameStore: GameStoreProtocol {

    @MockBehaviorWrapeer(value: [:])
    private(set) var playerCancellers: ValueObservable<[Disk : Canceller]>

    @MockBehaviorWrapeer(value: nil)
    private(set) var placeDiskCanceller: ValueObservable<Canceller?>

    @MockBehaviorWrapeer(value: false)
    private(set) var isDiskPlacing: ValueObservable<Bool>

    @MockBehaviorWrapeer(value: [])
    private(set) var cells: ValueObservable<[[GameData.Cell]]>

    @MockBehaviorWrapeer(value: .turn(.dark))
    private(set) var status: ValueObservable<GameData.Status>

    @MockBehaviorWrapeer(value: .manual)
    private(set) var playerDark: ValueObservable<GameData.Player>

    @MockBehaviorWrapeer(value: .manual)
    private(set) var playerLight: ValueObservable<GameData.Player>

    @MockBehaviorWrapeer(value: 0)
    private(set) var countOfDark: ValueObservable<Int>

    @MockBehaviorWrapeer(value: 0)
    private(set) var countOfLight: ValueObservable<Int>

    @MockBehaviorWrapeer(value: nil)
    private(set) var playerOfCurrentTurn: ValueObservable<GameData.Player?>

    @MockBehaviorWrapeer(value: nil)
    private(set) var sideWithMoreDisks: ValueObservable<Disk?>

    @MockPublishWrapper
    private(set) var faildToLoad: Observable<Void>

    @MockPublishWrapper
    private(set) var loaded: Observable<Void>

    @MockPublishWrapper
    private(set) var reset: Observable<Void>

    @MockResponse<Coordinate, Disk?>
    private(set) var diskAtCoordinate: Disk? = nil

    func disk(at coordinate: Coordinate) -> Disk? {
        cells.value[safe: coordinate.y]?[safe: coordinate.x]?.disk
        //_diskAtCoordinate.respond(coordinate)
    }
}
