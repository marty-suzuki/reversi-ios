import RxRelay
import RxSwift

public protocol GameStoreProtocol: AnyObject {
    var playerCancellers: ValueObservable<[Disk: Canceller]> { get }
    var placeDiskCanceller: ValueObservable<Canceller?> { get }
    var isDiskPlacing: ValueObservable<Bool> { get }
    var cells: ValueObservable<[[GameData.Cell]]> { get }
    var status: ValueObservable<GameData.Status> { get }
    var playerDark: ValueObservable<GameData.Player> { get }
    var playerLight: ValueObservable<GameData.Player> { get }
    var countOfDark: ValueObservable<Int> { get }
    var countOfLight: ValueObservable<Int> { get }
    var playerOfCurrentTurn: ValueObservable<GameData.Player?> { get }
    var sideWithMoreDisks: ValueObservable<Disk?> { get }
    var faildToLoad: Observable<Void> { get }
    var loaded: Observable<Void> { get }
    var reset: Observable<Void> { get }
}

public final class GameStore: GameStoreProtocol {

    @BehaviorWrapper(value: [:])
    public var playerCancellers: ValueObservable<[Disk: Canceller]>

    @BehaviorWrapper(value: nil)
    public var placeDiskCanceller: ValueObservable<Canceller?>

    @BehaviorWrapper(value: false)
    public var isDiskPlacing: ValueObservable<Bool>

    @BehaviorWrapper(value: [])
    public var cells: ValueObservable<[[GameData.Cell]]>

    @BehaviorWrapper(value: GameData.initial.status)
    public var status: ValueObservable<GameData.Status>

    @BehaviorWrapper(value: GameData.initial.playerDark)
    public var playerDark: ValueObservable<GameData.Player>

    @BehaviorWrapper(value: GameData.initial.playerLight)
    public var playerLight: ValueObservable<GameData.Player>

    @BehaviorWrapper(value: 0)
    public var countOfDark: ValueObservable<Int>

    @BehaviorWrapper(value: 0)
    public var countOfLight: ValueObservable<Int>

    @BehaviorWrapper(value: nil)
    public var playerOfCurrentTurn: ValueObservable<GameData.Player?>

    @BehaviorWrapper(value: nil)
    public var sideWithMoreDisks: ValueObservable<Disk?>

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

        dispatcher.setPlayerCancellerForDisk
            .withLatestFrom(playerCancellers) { ($0.0, $0.1, $1) }
            .map { canceller, disk, playerCancellers in
                var playerCancellers = playerCancellers
                if let canceller = canceller {
                    playerCancellers[disk] = canceller
                } else {
                    playerCancellers.removeValue(forKey: disk)
                }
                return playerCancellers
            }
            .bind(to: _playerCancellers)
            .disposed(by: disposeBag)

        dispatcher.setPlaceDiskCanceller
            .bind(to: _placeDiskCanceller)
            .disposed(by: disposeBag)

        let countOf: (Disk, [[GameData.Cell]]) -> Int = { disk, cells in
            cells.reduce(0) { result, rows in
                rows.reduce(result) { result, cell in
                    if cell.disk == disk {
                        return result + 1
                    } else {
                        return result
                    }
                }
            }
        }

        cells
            .map { countOf(.dark, $0) }
            .bind(to: _countOfDark)
            .disposed(by: disposeBag)

        cells
            .map { countOf(.light, $0) }
            .bind(to: _countOfLight)
            .disposed(by: disposeBag)

        Observable.combineLatest(status, playerDark, playerLight)
            .map { status, dark, light -> GameData.Player? in
                switch status {
                case .gameOver:  return nil
                case .turn(.dark): return dark
                case .turn(.light): return light
                }
            }
            .bind(to: _playerOfCurrentTurn)
            .disposed(by: disposeBag)

        Observable.combineLatest(countOfDark, countOfLight)
            .map { darkCount, lightCount -> Disk? in
                if darkCount == lightCount {
                    return nil
                } else {
                    return darkCount > lightCount ? .dark : .light
                }
            }
            .bind(to: _sideWithMoreDisks)
            .disposed(by: disposeBag)

        placeDiskCanceller
            .map { $0 != nil }
            .bind(to: _isDiskPlacing)
            .disposed(by: disposeBag)
    }
}
