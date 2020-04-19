import RxSwift

public protocol GameDataGettable: AnyObject {
    var status: ValueObservable<GameData.Status> { get }
    var playerDark: ValueObservable<GameData.Player> { get }
    var playerLight: ValueObservable<GameData.Player> { get }
    var cells: ValueObservable<[[GameData.Cell]]> { get }
    subscript(coordinate: Coordinate) -> Disk? { get }
}

public protocol GameDataSettable: AnyObject {
    subscript(coordinate: Coordinate) -> Disk? { get set }
    func load() -> Single<Void>
    func save() throws
    func reset()
    func setStatus(_ status: GameData.Status)
    func setPlayerOfDark(_ player: GameData.Player)
    func setPlayerOfLight(_ player: GameData.Player)
}

public protocol GameDataCacheProtocol: GameDataGettable, GameDataSettable {}

final class GameDataCache: GameDataCacheProtocol {

    private let _loadGame: GameDataIO.LoadGame
    private let _saveGame: GameDataIO.SaveGame

    @BehaviorWrapper(value: GameData.initial.status)
    private(set) var status: ValueObservable<GameData.Status>

    @BehaviorWrapper(value: GameData.initial.playerDark)
    private(set) var playerDark: ValueObservable<GameData.Player>

    @BehaviorWrapper(value: GameData.initial.playerLight)
    private(set) var playerLight: ValueObservable<GameData.Player>

    @BehaviorWrapper(value: [])
    private(set) var cells: ValueObservable<[[GameData.Cell]]>

    init(loadGame: @escaping GameDataIO.LoadGame,
        saveGame: @escaping GameDataIO.SaveGame,
        cells: [[GameData.Cell]] = GameData.initial.cells) {
        self._loadGame = loadGame
        self._saveGame = saveGame
        self._cells.accept(cells)
    }

    subscript(coordinate: Coordinate) -> Disk? {
        get {
            guard
                let cell = cells.value[safe: coordinate.y]?[safe: coordinate.x],
                cell.coordinate == coordinate
            else {
                return nil
            }
            return cell.disk
        }
        set {
            guard
                let cell = cells.value[safe: coordinate.y]?[safe: coordinate.x],
                cell.coordinate == coordinate
            else {
                return
            }
            var cells = self.cells.value
            cells[coordinate.y][coordinate.x].disk = newValue
            self._cells.accept(cells)
        }
    }

    func setPlayerOfDark(_ player: GameData.Player) {
        _playerDark.accept(player)
    }

    func setPlayerOfLight(_ player: GameData.Player) {
        _playerLight.accept(player)
    }

    func setStatus(_ status: GameData.Status) {
        _status.accept(status)
    }

    func load() -> Single<Void> {
        return Single<Void>.create { [weak self] observer in
            do {
                try self?._loadGame({ try String(contentsOfFile: $0, encoding: .utf8) }) { data in
                    self?._status.accept(data.status)
                    self?._playerDark.accept(data.playerDark)
                    self?._playerLight.accept(data.playerLight)
                    self?._cells.accept(data.cells)
                    observer(.success(()))
                }
            } catch {
                observer(.error(error))
            }
            return Disposables.create()
        }
    }

    func save() throws {
        let data = GameData(status: status.value,
                            playerDark: playerDark.value,
                            playerLight: playerLight.value,
                            cells: cells.value)
        try _saveGame(
            data,
            { try $0.write(toFile: $1, atomically: true, encoding: .utf8) }
        )
    }

    func reset() {
        self._cells.accept(GameData.initial.cells)
        self._status.accept(GameData.initial.status)
        self._playerDark.accept(GameData.initial.playerDark)
        self._playerLight.accept(GameData.initial.playerLight)
    }
}
