import RxCocoa
import RxSwift

@dynamicMemberLookup
public protocol GameLogicProtocol: GameDataSettable {
    var playerCancellers: [Disk: Canceller] { get set }
    var countOfDark: ValueObservable<Int> { get }
    var countOfLight: ValueObservable<Int> { get }
    var playerOfCurrentTurn:  ValueObservable<GameData.Player?> { get }
    var sideWithMoreDisks: ValueObservable<Disk?> { get }
    var playTurnOfComputer: Observable<Void> { get }
    var gameLoaded: Observable<Void> { get }
    var newGameBegan: Observable<Void> { get }
    func flippedDiskCoordinates(by disk: Disk,
                                at coordinate: Coordinate) -> [Coordinate]
    func validMoves(for disk: Disk) -> [Coordinate]
    func waitForPlayer()
    func setPlayer(for disk: Disk, with index: Int)
    func startGame()
    func newGame()
    func setDisk(_ disk: Disk?, at coordinate: Coordinate)

    subscript<T>(dynamicMember keyPath: KeyPath<GameDataGettable, ValueObservable<T>>) -> ValueObservable<T> { get }
}

final class GameLogic: GameLogicProtocol {

    var playerCancellers: [Disk: Canceller] = [:]

    @BehaviorWrapper(value: 0)
    private(set) var countOfDark: ValueObservable<Int>

    @BehaviorWrapper(value: 0)
    private(set) var countOfLight: ValueObservable<Int>

    @BehaviorWrapper(value: nil)
    private(set) var playerOfCurrentTurn: ValueObservable<GameData.Player?>

    @BehaviorWrapper(value: nil)
    private(set) var sideWithMoreDisks: ValueObservable<Disk?>

    @PublishWrapper
    private(set) var playTurnOfComputer: Observable<Void>

    @PublishWrapper
    private(set) var gameLoaded: Observable<Void>

    @PublishWrapper
    private(set) var newGameBegan: Observable<Void>

    private let cache: GameDataCacheProtocol
    private let disposeBag = DisposeBag()

    private let _startGame = PublishRelay<Void>()
    private let _newGame = PublishRelay<Void>()

    init(cache: GameDataCacheProtocol) {
        self.cache = cache

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

        cache.cells
            .map { countOf(.dark, $0) }
            .bind(to: _countOfDark)
            .disposed(by: disposeBag)

        cache.cells
            .map { countOf(.light, $0) }
            .bind(to: _countOfLight)
            .disposed(by: disposeBag)

        Observable.combineLatest(cache.status, cache.playerDark, cache.playerLight)
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

        _startGame
            .flatMap { [cache] _ -> Observable<Void> in
                cache.load().asObservable()
            }
            .subscribe(onNext: { [weak self] in
                self?._gameLoaded.accept()
            }, onError: { [weak self] _ in
                self?._newGame.accept(())
            })
            .disposed(by: disposeBag)

        _newGame
            .subscribe(onNext: { [weak self, cache] in
                cache.reset()
                self?._newGameBegan.accept()
                try? cache.save()
            })
            .disposed(by: disposeBag)
    }

    subscript<T>(dynamicMember keyPath: KeyPath<GameDataGettable, ValueObservable<T>>) -> ValueObservable<T> {
        cache[keyPath: keyPath]
    }

    func flippedDiskCoordinates(by disk: Disk,
                                at coordinate: Coordinate) -> [Coordinate] {
        let directions = [
            (x: -1, y: -1),
            (x:  0, y: -1),
            (x:  1, y: -1),
            (x:  1, y:  0),
            (x:  1, y:  1),
            (x:  0, y:  1),
            (x: -1, y:  0),
            (x: -1, y:  1),
        ]

        guard cache.cells.value[safe: coordinate.y]?[safe: coordinate.x]?.disk == nil else {
            return []
        }

        var diskCoordinates: [Coordinate] = []

        for direction in directions {
            var x = coordinate.x
            var y = coordinate.y

            var diskCoordinatesInLine: [Coordinate] = []
            flipping: while true {
                x += direction.x
                y += direction.y

                switch (disk, cache.cells.value[safe: y]?[safe: x]?.disk) { // Uses tuples to make patterns exhaustive
                case (.dark, .dark?), (.light, .light?):
                    diskCoordinates.append(contentsOf: diskCoordinatesInLine)
                    break flipping
                case (.dark, .light?), (.light, .dark?):
                    diskCoordinatesInLine.append(Coordinate(x: x, y: y))
                case (_, .none):
                    break flipping
                }
            }
        }

        return diskCoordinates
    }

    func canPlace(disk: Disk, at coordinate: Coordinate) -> Bool {
        !flippedDiskCoordinates(by: disk, at: coordinate).isEmpty
    }

    func validMoves(for disk: Disk) -> [Coordinate] {
        cache.cells.value.reduce([Coordinate]()) { result, rows in
            rows.reduce(result) { result, cell in
                if canPlace(disk: disk, at: cell.coordinate) {
                    return result + [cell.coordinate]
                } else {
                    return result
                }
            }
        }
    }

    func waitForPlayer() {
        let player: GameData.Player
        switch cache.status.value {
        case .gameOver:
            return
        case .turn(.dark):
            player = cache.playerDark.value
        case .turn(.light):
            player = cache.playerLight.value
        }

        switch player {
        case .manual:
            break
        case .computer:
            _playTurnOfComputer.accept()
        }
    }

    func setPlayer(for disk: Disk, with index: Int) {
        switch disk {
        case .dark:
            cache.setPlayerOfDark(GameData.Player(rawValue: index) ?? .manual)
        case .light:
            cache.setPlayerOfLight(GameData.Player(rawValue: index) ?? .manual)
        }

        try? cache.save()

        if let canceller = playerCancellers[disk] {
            canceller.cancel()
        }

        let player: GameData.Player
        switch disk {
        case .dark:
            player = cache.playerDark.value
        case .light:
            player = cache.playerLight.value
        }

        if cache.status.value == .turn(disk), case .computer = player {
            _playTurnOfComputer.accept()
        }
    }

    func startGame() {
        _startGame.accept(())
    }

    func newGame() {
        _newGame.accept(())
    }
}

extension GameLogic {

    func save() throws {
        try cache.save()
    }

    func setStatus(_ status: GameData.Status) {
        cache.setStatus(status)
    }

    func setPlayerOfDark(_ player: GameData.Player) {
        cache.setPlayerOfDark(player)
    }

    func setPlayerOfLight(_ player: GameData.Player) {
        cache.setPlayerOfLight(player)
    }

    func setDisk(_ disk: Disk?, at coordinate: Coordinate) {
        cache[coordinate] = disk
    }
}
