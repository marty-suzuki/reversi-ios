import RxRelay
import RxSwift

public protocol GameStoreProtocol: AnyObject {
    var cells: ValueObservable<[[GameData.Cell]]> { get }
    var status: ValueObservable<GameData.Status> { get }
    var playerDark: ValueObservable<GameData.Player> { get }
    var playerLight: ValueObservable<GameData.Player> { get }
    var faildToLoad: Observable<Void> { get }
    var loaded: Observable<Void> { get }
    var reset: Observable<Void> { get }
    func disk(at coordinate: Coordinate) -> Disk?
}

public final class GameStore: GameStoreProtocol {

    @BehaviorWrapper(value: [])
    public private(set) var cells: ValueObservable<[[GameData.Cell]]>

    @BehaviorWrapper(value: GameData.initial.status)
    public private(set) var status: ValueObservable<GameData.Status>

    @BehaviorWrapper(value: GameData.initial.playerDark)
    public private(set) var playerDark: ValueObservable<GameData.Player>

    @BehaviorWrapper(value: GameData.initial.playerLight)
    public private(set) var playerLight: ValueObservable<GameData.Player>

    public let faildToLoad: Observable<Void>
    public let loaded: Observable<Void>
    public let reset: Observable<Void>

    private let disposeBag = DisposeBag()

    public init(dispatcher: GameDispatcher) {
        self.faildToLoad = dispatcher.faildToLoad.asObservable()
        self.loaded = dispatcher.loaded.asObservable()
        self.reset = dispatcher.reset.asObservable()

        dispatcher.setCells
            .bind(to: _cells)
            .disposed(by: disposeBag)

        dispatcher.setStatus
            .bind(to: _status)
            .disposed(by: disposeBag)

        dispatcher.setPlayerOfDark
            .bind(to: _playerDark)
            .disposed(by: disposeBag)

        dispatcher.setPlayerOfLight
            .bind(to: _playerLight)
            .disposed(by: disposeBag)

        dispatcher.setDiskAtCoordinate
            .withLatestFrom(cells) { ($1, $0.0, $0.1) }
            .flatMap { cells, disk, coordinate -> Observable<[[GameData.Cell]]> in
                guard
                    let cell = cells[safe: coordinate.y]?[safe: coordinate.x],
                    cell.coordinate == coordinate
                else {
                    return .empty()
                }
                var cells = cells
                cells[coordinate.y][coordinate.x].disk = disk
                return .just(cells)
            }
            .bind(to: _cells)
            .disposed(by: disposeBag)
    }

    public func disk(at coordinate: Coordinate) -> Disk? {
        guard
            let cell = cells.value[safe: coordinate.y]?[safe: coordinate.x],
            cell.coordinate == coordinate
        else {
            return nil
        }
        return cell.disk
    }
}
