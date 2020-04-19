import Foundation

public protocol GameDataCellGettable: AnyObject {
    var cells: [[GameData.Cell]] { get }
}

public protocol GemeDataDiskGettable: AnyObject {
     subscript(coordinate: Coordinate) -> Disk? { get }
}

public protocol GameDataCacheProtocol: GameDataCellGettable, GemeDataDiskGettable {
    var status: GameData.Status { get set }
    var playerOfCurrentTurn: GameData.Player? { get }
    var playerDark: ValueObservable<GameData.Player> { get }
    var playerLight: ValueObservable<GameData.Player> { get }
    subscript(coordinate: Coordinate) -> Disk? { get set }
    func load(completion: @escaping () -> Void) throws
    func save() throws
    func reset()
    func setPlayerOfDark(_ player: GameData.Player)
    func setPlayerOfLight(_ player: GameData.Player)
}

public enum GameDataCacheFactory {
    public static func make() -> GameDataCacheProtocol {
        GameDataCache(loadGame: GameDataIO.loadGame,
                      saveGame: GameDataIO.save)
    }
}

final class GameDataCache: GameDataCacheProtocol {

    private let _loadGame: GameDataIO.LoadGame
    private let _saveGame: GameDataIO.SaveGame

    var status: GameData.Status = GameData.initial.status

    @BehaviorWrapper(value: GameData.initial.playerDark)
    private(set) var playerDark: ValueObservable<GameData.Player>

    @BehaviorWrapper(value: GameData.initial.playerLight)
    private(set) var playerLight: ValueObservable<GameData.Player>

    private(set) var cells: [[GameData.Cell]]

    var playerOfCurrentTurn: GameData.Player? {
        switch status {
        case .gameOver:
            return nil
        case .turn(.dark):
            return playerDark.value
        case .turn(.light):
            return playerLight.value
        }
    }

    init(
        loadGame: @escaping GameDataIO.LoadGame,
        saveGame: @escaping GameDataIO.SaveGame,
        cells: [[GameData.Cell]] = GameData.initial.cells
    ) {
        self._loadGame = loadGame
        self._saveGame = saveGame
        self.cells = cells
    }

    subscript(coordinate: Coordinate) -> Disk? {
        get {
            guard
                let cell = cells[safe: coordinate.y]?[safe: coordinate.x],
                cell.coordinate == coordinate
            else {
                return nil
            }
            return cell.disk
        }
        set {
            guard
                let cell = cells[safe: coordinate.y]?[safe: coordinate.x],
                cell.coordinate == coordinate
            else {
                return
            }
            cells[coordinate.y][coordinate.x].disk = newValue
        }
    }

    func setPlayerOfDark(_ player: GameData.Player) {
        _playerDark.accept(player)
    }

    func setPlayerOfLight(_ player: GameData.Player) {
        _playerLight.accept(player)
    }

    func load(completion: @escaping () -> Void) throws {
        try _loadGame({ try String(contentsOfFile: $0, encoding: .utf8) }) { [weak self] data in
            self?.status = data.status
            self?._playerDark.accept(data.playerDark)
            self?._playerLight.accept(data.playerLight)
            self?.cells = data.cells
            completion()
        }
    }

    func save() throws {
        let data = GameData(status: status,
                            playerDark: playerDark.value,
                            playerLight: playerLight.value,
                            cells: cells)
        try _saveGame(
            data,
            { try $0.write(toFile: $1, atomically: true, encoding: .utf8) }
        )
    }

    func reset() {
        self.cells = GameData.initial.cells
        self.status = GameData.initial.status
        self._playerDark.accept(GameData.initial.playerDark)
        self._playerLight.accept(GameData.initial.playerLight)
    }
}
