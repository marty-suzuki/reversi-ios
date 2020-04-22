@testable import ReversiLogic

final class MockGameActionCreator: GameActionCreatorProtocol {

    @MockResponse<Void, Void>()
    var _load: Void

    @MockResponse<SaveParameters, Void>()
    var _save: Void

    @MockResponse<Void, Void>()
    var _reset: Void

    @MockResponse<GameData.Player, Void>()
    var _setPlayerOfDark: Void

    @MockResponse<GameData.Player, Void>()
    var _setPlayerOfLight: Void

    @MockResponse<GameData.Status, Void>()
    var _setStatus: Void

    @MockResponse<SetDiskParameters, Void>()
    var _setDisk: Void

    func load() {
        __load.respond()
    }

    func save(cells: [[GameData.Cell]], status: GameData.Status, playerDark: GameData.Player, playerLight: GameData.Player) {
        __save.respond(.init(cells: cells, status: status, playerDark: playerDark, playerLight: playerLight))
    }

    func reset() {
        __reset.respond()
    }

    func setPlayerOfDark(_ player: GameData.Player) {
        __setPlayerOfDark.respond(player)
    }

    func setPlayerOfLight(_ player: GameData.Player) {
        __setPlayerOfLight.respond(player)
    }

    func setStatus(_ status: GameData.Status) {
        __setStatus.respond(status)
    }

    func setDisk(_ disk: Disk?, at coordinate: Coordinate) {
        __setDisk.respond(.init(disk: disk, coordinate: coordinate))
    }
}

extension MockGameActionCreator {

    struct SaveParameters: Equatable {
        let cells: [[GameData.Cell]]
        let status: GameData.Status
        let playerDark: GameData.Player
        let playerLight: GameData.Player
    }

    struct SetDiskParameters: Equatable {
        let disk: Disk?
        let coordinate: Coordinate
    }
}
