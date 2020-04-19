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
    subscript(coordinate: Coordinate) -> Disk? { get set }
    subscript(disk: Disk) -> GameData.Player { get set }
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

    var status: GameData.Status = GameData.initial.status
    private(set) var playerDark: GameData.Player
    private(set) var playerLight: GameData.Player
    private(set) var cells: [[GameData.Cell]]

    var playerOfCurrentTurn: GameData.Player? {
        switch status {
        case .gameOver:
            return nil
        case let .turn(disk):
            return self[disk]
        }
    }

    init(
        loadGame: @escaping GameDataIO.LoadGame,
        saveGame: @escaping GameDataIO.SaveGame,
        playerDark: GameData.Player = GameData.initial.playerDark,
        playerLight: GameData.Player = GameData.initial.playerLight,
        cells: [[GameData.Cell]] = GameData.initial.cells
    ) {
        self._loadGame = loadGame
        self._saveGame = saveGame
        self.playerDark = playerDark
        self.playerLight = playerLight
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

    subscript(disk: Disk) -> GameData.Player {
        get {
            switch disk {
            case .dark: return playerDark
            case .light: return playerLight
            }
        }
        set {
            switch disk {
            case .dark: playerDark = newValue
            case .light: playerLight = newValue
            }
        }
    }

    func load(completion: @escaping () -> Void) throws {
        try _loadGame({ try String(contentsOfFile: $0, encoding: .utf8) }) { [weak self] data in
            self?.status = data.status
            self?.playerDark = data.playerDark
            self?.playerLight = data.playerLight
            self?.cells = data.cells
            completion()
        }
    }

    func save() throws {
        let data = GameData(status: status,
                            playerDark: playerDark,
                            playerLight: playerLight,
                            cells: cells)
        try _saveGame(
            data,
            { try $0.write(toFile: $1, atomically: true, encoding: .utf8) }
        )
    }

    func reset() {
        self.cells = GameData.initial.cells
        self.status = GameData.initial.status
        self.playerDark = GameData.initial.playerDark
        self.playerLight = GameData.initial.playerLight
    }
}
