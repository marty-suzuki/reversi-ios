@testable import ReversiLogic

final class MockGameDataCache: GameDataCacheProtocol {

    var status: GameData.Status = .turn(.dark)
    var player: GameData.Player = .manual
    var cells: [[GameData.Board.Cell]] = []

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

    @MockResponse<Disk, GameData.Player>
    var _getPlayerDark = .manual

    @MockResponse<SetPlayer, Void>()
    var _setPalyerDark: Void

    @MockResponse<Disk, GameData.Player>
    var _getPlayerLight = .manual

    @MockResponse<SetPlayer, Void>()
    var _setPalyerLight: Void

    subscript(coordinate: Coordinate) -> Disk? {
        get { __getDisk.respond(coordinate) }
        set { __setDisk.respond((coordinate, newValue)) }
    }

    subscript(disk: Disk) -> GameData.Player {
        get {
            switch disk {
            case .dark: return __getPlayerDark.respond(disk)
            case .light: return __getPlayerLight.respond(disk)
            }
        }
        set {
            let response = SetPlayer(disk: disk, player: newValue)
            switch disk {
            case .dark: __setPalyerDark.respond(response)
            case .light: __setPalyerLight.respond(response)
            }
        }
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
