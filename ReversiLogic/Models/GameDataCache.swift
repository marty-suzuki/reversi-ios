import Foundation

public protocol GameDataCacheProtocol: AnyObject {
    var status: GameData.Status { get set }
    var playerDark: GameData.Player { get set }
    var playerLight: GameData.Player { get set }
    var cells: [[GameData.Board.Cell]] { get }
    subscript(coordinate: Coordinate) -> Disk? { get set }
    func load(completion: @escaping () -> Void) throws
    func save() throws
    func reset()
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

    var status: GameData.Status = .turn(.dark)
    var playerDark: GameData.Player = .manual
    var playerLight: GameData.Player = .manual
    private(set) var cells: [[GameData.Board.Cell]]

    init(
        loadGame: @escaping GameDataIO.LoadGame,
        saveGame: @escaping GameDataIO.SaveGame,
        cells: [[GameData.Board.Cell]] = GameData.Board.initial().cells
    ) {
        self._loadGame = loadGame
        self._saveGame = saveGame
        self.cells = cells
    }

    subscript(coordinate: Coordinate) -> Disk? {
        get {
            guard
                let cell = cells[safe: coordinate.y]?[safe: coordinate.x],
                cell.x == coordinate.x && cell.y == coordinate.y
            else {
                return nil
            }
            return cell.disk
        }
        set {
            guard
                let cell = cells[safe: coordinate.y]?[safe: coordinate.x],
                cell.x == coordinate.x && cell.y == coordinate.y
            else {
                return
            }
            cells[coordinate.y][coordinate.x].disk = newValue
        }
    }

    func load(completion: @escaping () -> Void) throws {
        try _loadGame({ try String(contentsOfFile: $0, encoding: .utf8) }) { [weak self] data in
            self?.status = data.status
            self?.playerDark = data.playerDark
            self?.playerLight = data.playerLight
            self?.cells = data.board.cells
            completion()
        }
    }

    func save() throws {
        let data = GameData(status: status,
                            playerDark: playerDark,
                            playerLight: playerLight,
                            board: .init(cells: cells))
        try _saveGame(
            data,
            { try $0.write(toFile: $1, atomically: true, encoding: .utf8) }
        )
    }

    func reset() {
        self.cells = GameData.Board.initial().cells
        self.status = .turn(.dark)
        self.playerDark = .manual
        self.playerLight = .manual
    }
}
