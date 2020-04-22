import RxRelay

public final class GameDispatcher {
    let reset = PublishRelay<Void>()
    let loaded = PublishRelay<Void>()
    let faildToLoad = PublishRelay<Void>()
    let setCells = PublishRelay<[[GameData.Cell]]>()
    let setPlayerOfDark = PublishRelay<GameData.Player>()
    let setPlayerOfLight = PublishRelay<GameData.Player>()
    let setStatus = PublishRelay<GameData.Status>()
    let setDiskAtCoordinate = PublishRelay<(Disk?, Coordinate)>()
    let setPlayerCancellerForDisk = PublishRelay<(Canceller?, Disk)>()
    let setPlaceDiskCanceller = PublishRelay<Canceller?>()
}
