import RxSwift

public protocol GameDataCacheProtocol {
    func save(data: GameData) -> Single<Void>
    func load() -> Single<GameData>
}

final class GameDataCache: GameDataCacheProtocol {

    private let _loadGame: GameDataIO.LoadGame
    private let _saveGame: GameDataIO.SaveGame

    init(loadGame: @escaping GameDataIO.LoadGame,
         saveGame: @escaping GameDataIO.SaveGame) {
        self._loadGame = loadGame
        self._saveGame = saveGame
    }

    func load() -> Single<GameData> {
        return Single<GameData>.create { [weak self] observer in
            do {
                try self?._loadGame({ try String(contentsOfFile: $0, encoding: .utf8) }) { data in
                    observer(.success((data)))
                }
            } catch {
                observer(.error(error))
            }
            return Disposables.create()
        }
    }

    func save(data: GameData) -> Single<Void> {
        Single<Void>.create { [weak self] observer in
            do {
                try self?._saveGame(
                    data,
                    { try $0.write(toFile: $1, atomically: true, encoding: .utf8) }
                )
                observer(.success(()))
            } catch {
                observer(.error(error))
            }
            return Disposables.create()
        }
    }
}
