import RxSwift

public protocol GameLogicFactoryProtocol {
    func make() -> GameLogicProtocol
}

public struct GameLogicFactory: GameLogicFactoryProtocol {

    public init() {}

    public func make() -> GameLogicProtocol {
        let cache = GameDataCache(loadGame: GameDataIO.loadGame,
                                  saveGame: GameDataIO.save)
        let dispatcher = GameDispatcher()
        let actionCreator = GameActionCreator(dispatcher: dispatcher,
                                              cache: cache)
        let store = GameStore(dispatcher: dispatcher)
        return GameLogic(actionCreator: actionCreator,
                         store: store,
                         mainScheduler: MainScheduler.instance)
    }
}
