import RxSwift

public protocol GameLogicFactoryProtocol {
    var actionCreator: GameActionCreator { get }
    var store: GameStore { get }
    func make() -> GameLogicProtocol
}

public struct GameLogicFactory: GameLogicFactoryProtocol {

    public let actionCreator: GameActionCreator
    public let store: GameStore

    public init() {
        let cache = GameDataCache(loadGame: GameDataIO.loadGame,
                                  saveGame: GameDataIO.save)
        let dispatcher = GameDispatcher()
        self.actionCreator = GameActionCreator(dispatcher: dispatcher,
                                              cache: cache)
        self.store = GameStore(dispatcher: dispatcher)
    }

    public func make() -> GameLogicProtocol {
        return GameLogic(actionCreator: actionCreator,
                         store: store,
                         mainScheduler: MainScheduler.instance)
    }
}
