import RxRelay
import RxSwift

public protocol GameActionCreatorProtocol: AnyObject {
    func load()
    func save(cells: [[GameData.Cell]],
              status: GameData.Status,
              playerDark: GameData.Player,
              playerLight: GameData.Player)
    func reset()
    func setPlayerOfDark(_ player: GameData.Player)
    func setPlayerOfLight(_ player: GameData.Player)
    func setStatus(_ status: GameData.Status)
    func setDisk(_ disk: Disk?, at coordinate: Coordinate)
}

public final class GameActionCreator: GameActionCreatorProtocol {

    private let disposeBag = DisposeBag()
    private let _save = PublishRelay<GameData>()
    private let _load = PublishRelay<Void>()
    private let _reset = PublishRelay<Void>()
    private let dispatcher: GameDispatcher

    public init(dispatcher: GameDispatcher,
                cache: GameDataCacheProtocol) {
        self.dispatcher = dispatcher
        _save
            .flatMap { cache.save(data: $0) }
            .subscribe()
            .disposed(by: disposeBag)

        let update = _load
            .flatMap { _ -> Single<(GameData, GameDispatcher.ReasonOfUpdate)> in
                cache.load()
                    .map { ($0, .loaded) }
                    .catchError { _ in Single.just((.initial, .faildToLoad)) }
            }

        Observable.merge(
            update,
            _reset.map { (GameData.initial, .reset) }
            )
            .subscribe(onNext: { data, reasonOfUpdate in
                dispatcher.setCells.accept(data.cells)
                dispatcher.setStatus.accept(data.status)
                dispatcher.setPlayerOfDark.accept(data.playerDark)
                dispatcher.setPlayerOfLight.accept(data.playerLight)
                dispatcher.reasonOfUpdate.accept(reasonOfUpdate)
            })
            .disposed(by: disposeBag)
    }

    public func load() {
        _load.accept(())
    }

    public func save(cells: [[GameData.Cell]],
                     status: GameData.Status,
                     playerDark: GameData.Player,
                     playerLight: GameData.Player) {
        _save.accept(GameData(status: status,
                              playerDark: playerDark,
                              playerLight: playerLight,
                              cells: cells))
    }

    public func reset() {
        _reset.accept(())
    }

    public func setPlayerOfDark(_ player: GameData.Player) {
        dispatcher.setPlayerOfDark.accept(player)
    }

    public func setPlayerOfLight(_ player: GameData.Player) {
        dispatcher.setPlayerOfLight.accept(player)
    }

    public func setStatus(_ status: GameData.Status) {
        dispatcher.setStatus.accept(status)
    }

    public func setDisk(_ disk: Disk?, at coordinate: Coordinate) {
        dispatcher.setDiskAtCoordinate.accept((disk, coordinate))
    }
}
