public protocol GameLogicFactoryProtocol {
    func make() -> GameLogicProtocol
}

public struct GameLogicFactory: GameLogicFactoryProtocol {

    public init() {}

    public func make() -> GameLogicProtocol {
        let cache = GameDataCache(loadGame: GameDataIO.loadGame,
                                  saveGame: GameDataIO.save)
        return GameLogic(cache: cache)
    }
}
