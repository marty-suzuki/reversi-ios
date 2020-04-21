import RxRelay

public final class GameDispatcher {
    let reasonOfUpdate = PublishRelay<ReasonOfUpdate>()
    let setCells = PublishRelay<[[GameData.Cell]]>()
    let setPlayerOfDark = PublishRelay<GameData.Player>()
    let setPlayerOfLight = PublishRelay<GameData.Player>()
    let setStatus = PublishRelay<GameData.Status>()
    let setDiskAtCoordinate = PublishRelay<(Disk?, Coordinate)>()
}

extension GameDispatcher {
    enum ReasonOfUpdate {
        case reset
        case loaded
        case faildToLoad
    }
}
