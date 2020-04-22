import RxSwift
@testable import ReversiLogic

struct MockGameLogicFactory: GameLogicFactoryProtocol {

    private let logic: MockGameLogic

    init(logic: MockGameLogic) {
        self.logic = logic
    }

    func make() -> GameLogicProtocol {
        logic
    }
}

final class MockGameLogic: GameLogicProtocol {

    @MockPublishWrapper
    private(set) var willTurnDiskOfComputer: Observable<Disk>

    @MockPublishWrapper
    private(set) var didTurnDiskOfComputer: Observable<Disk>

    @MockPublishWrapper
    private(set) var gameLoaded: Observable<Void>

    @MockPublishWrapper
    private(set) var newGameBegan: Observable<Void>

    @MockPublishWrapper
     private(set) var handleDiskWithCoordinate: Observable<(Disk, Coordinate)>

    @CountableProperty
    var playerCancellers: [Disk : Canceller] = [:]

    @CountableProperty
    var placeDiskCanceller: Canceller?

    @MockResponse<FlippedDiskCoordinates, [Coordinate]>
    var _flippedDiskCoordinates = []

    @MockResponse<Disk, [Coordinate]>
    var _validMovekForDark = []

    @MockResponse<Disk, [Coordinate]>
    var _validMovekForLight = []

    @MockResponse<Void, Void>()
    var _waitForPlayer: Void

    @MockResponse<SetPlayer, Void>()
    var _setPlayer: Void

    @MockResponse<Void, Void>()
    var _startGame: Void

    @MockResponse<Void, Void>()
    var _newGame: Void

    @MockResponse<SetDiskParameters, Void>()
    var _setDisk: Void

    @MockResponse<GameData.Status, Void>()
    var _setStatus: Void

    @MockResponse<Coordinate, Void>()
    var _handleSelectedCoordinate: Void

    @MockResponse<Void, Void>()
    var _save: Void

    let store = MockGameStore()

    func flippedDiskCoordinates(by disk: Disk, at coordinate: Coordinate) -> [Coordinate] {
        __flippedDiskCoordinates.respond(.init(disk: disk, coordinate: coordinate))
    }

    func validMoves(for disk: Disk) -> [Coordinate] {
        switch disk {
        case .dark:
            return __validMovekForDark.respond(disk)
        case .light:
            return __validMovekForLight.respond(disk)
        }
    }

    func waitForPlayer() {
        __waitForPlayer.respond()
    }

    func setPlayer(for disk: Disk, with index: Int) {
        __setPlayer.respond(.init(disk: disk, index: index))
    }

    func startGame() {
        __startGame.respond()
    }

    func newGame() {
        __newGame.respond()
    }

    func handle(selectedCoordinate: Coordinate) {
        __handleSelectedCoordinate.respond(selectedCoordinate)
    }

    func save() {
        __save.respond()
    }

    func setStatus(_ status: GameData.Status) {
        __setStatus.respond(status)
    }

    func setDisk(_ disk: Disk?, at coordinate: Coordinate) {
        __setDisk.respond(.init(disk: disk, coordinate: coordinate))
    }
}

extension MockGameLogic {

    subscript<T>(dynamicMember keyPath: KeyPath<GameStoreProtocol, ValueObservable<T>>) -> ValueObservable<T> {
        store[keyPath: keyPath]
    }
}

extension MockGameLogic {
    struct FlippedDiskCoordinates: Equatable {
        let disk: Disk
        let coordinate: Coordinate
    }

    struct SetDiskParameters: Equatable {
        let disk: Disk?
        let coordinate: Coordinate
    }

    struct SetPlayer: Equatable {
        let disk: Disk
        let index: Int
    }
}
