import RxSwift
import RxTest
@testable import ReversiLogic

final class MockGameStore: GameStoreProtocol {

    @MockBehaviorWrapeer(value: [])
    var cells: ValueObservable<[[GameData.Cell]]>

    @MockBehaviorWrapeer(value: .turn(.dark))
    var status: ValueObservable<GameData.Status>

    @MockBehaviorWrapeer(value: .manual)
    var playerDark: ValueObservable<GameData.Player>

    @MockBehaviorWrapeer(value: .manual)
    var playerLight: ValueObservable<GameData.Player>

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
