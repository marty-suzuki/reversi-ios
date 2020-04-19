import RxSwift

public protocol GameLogicFactoryProtocol {
    func make(cache: GameDataGettable) -> GameLogicProtocol
}

public struct GameLogicFactory: GameLogicFactoryProtocol {

    public init() {}

    public func make(cache: GameDataGettable) -> GameLogicProtocol {
        GameLogic(cache: cache)
    }
}

public protocol GameLogicProtocol: AnyObject {
    var countOfDark: ValueObservable<Int> { get }
    var countOfLight: ValueObservable<Int> { get }
    var playerOfCurrentTurn:  ValueObservable<GameData.Player?> { get }
    var sideWithMoreDisks: ValueObservable<Disk?> { get }
    func flippedDiskCoordinates(by disk: Disk,
                                at coordinate: Coordinate) -> [Coordinate]
    func validMoves(for disk: Disk) -> [Coordinate]
}

final class GameLogic: GameLogicProtocol {

    @BehaviorWrapper(value: 0)
    private(set) var countOfDark: ValueObservable<Int>

    @BehaviorWrapper(value: 0)
    private(set) var countOfLight: ValueObservable<Int>

    @BehaviorWrapper(value: nil)
    private(set) var playerOfCurrentTurn: ValueObservable<GameData.Player?>

    @BehaviorWrapper(value: nil)
    private(set) var sideWithMoreDisks: ValueObservable<Disk?>

    private let cache: GameDataGettable
    private let disposeBag = DisposeBag()

    init(cache: GameDataGettable) {
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
}
