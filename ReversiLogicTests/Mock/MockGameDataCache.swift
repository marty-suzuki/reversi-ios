@testable import ReversiLogic

final class MockGameDataCache: GameDataCacheProtocol {

    @MockBehaviorWrapeer(value: .manual)
    private(set) var playerDark: ValueObservable<GameData.Player>

    @MockBehaviorWrapeer(value: .manual)
    private(set) var playerLight: ValueObservable<GameData.Player>

    var playerOfCurrentTurn: GameData.Player?

    @MockBehaviorWrapeer(value: .turn(.dark))
    var status: ValueObservable<GameData.Status>

    var cells: [[GameData.Cell]] = []

    @MockResponse<Void, Void>()
    var _load: Void

    @MockResponse<Void, Void>()
    var _save: Void

    @MockResponse<Void, Void>()
    var _reset: Void

    @MockResponse<Coordinate, Disk?>
    var _getDisk = nil

    @MockResponse<(Coordinate, Disk?), Void>()
    var _setDisk: Void

    @MockResponse<GameData.Player, Void>()
    var _setPalyerDark: Void

    @MockResponse<GameData.Player, Void>()
    var _setPalyerLight: Void

    @MockResponse<GameData.Status, Void>()
    var _setStatus: Void

    subscript(coordinate: Coordinate) -> Disk? {
        get { __getDisk.respond(coordinate) }
        set { __setDisk.respond((coordinate, newValue)) }
    }

    func setPlayerOfDark(_ player: GameData.Player) {
        __setPalyerDark.respond(player)
    }

    func setPlayerOfLight(_ player: GameData.Player) {
        __setPalyerLight.respond(player)
    }

    func setStatus(_ status: GameData.Status) {
        __setStatus.respond(status)
    }

    func load(completion: @escaping () -> Void) throws {
        __load.respond()
        completion()
    }

    func save() throws {
        __save.respond()
    }

    func reset() {
        __reset.respond()
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
