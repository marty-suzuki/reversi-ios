import RxSwift
@testable import ReversiLogic

final class MockGameDataCache: GameDataCacheProtocol {

    @MockPublishResponse<GameData, Void>()
    var _save: AnyObserver<Void>

    @MockPublishResponse<Void, GameData>()
    var _load: AnyObserver<GameData>

    func save(data: GameData) -> Single<Void> {
        __save.respond(data).asSingle()
    }

    func load() -> Single<GameData> {
        __load.respond().asSingle()
    }
}

extension MockGameDataCache {
    struct GetPlayer: Equatable {
        let coordinate: Coordinate
        let disk: Disk?
    }

    struct SetPlayer: Equatable {
        let disk: Disk
        let player: GameData.Player
    }
}
