import Foundation

public protocol GameDataCacheProtocol: AnyObject {
    func load(completion: @escaping (GameData) -> Void) throws
    func save(data: GameData) throws
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

    init(
        loadGame: @escaping GameDataIO.LoadGame,
        saveGame: @escaping GameDataIO.SaveGame
    ) {
        self._loadGame = loadGame
        self._saveGame = saveGame
    }

    func load(completion: @escaping (GameData) -> Void) throws {
        try _loadGame({ try String(contentsOfFile: $0, encoding: .utf8) }, completion)
    }

    func save(data: GameData) throws {
        try _saveGame(
            data,
            { try $0.write(toFile: $1, atomically: true, encoding: .utf8) }
        )
    }
}
