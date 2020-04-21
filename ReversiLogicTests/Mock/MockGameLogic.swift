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

    @MockPublishWrapper
    private(set) var playTurnOfComputer: Observable<Void>

    @MockBehaviorWrapeer(value: 0)
    private(set) var countOfDark: ValueObservable<Int>

    @MockBehaviorWrapeer(value: 0)
    private(set) var countOfLight: ValueObservable<Int>

    @MockBehaviorWrapeer(value: nil)
    private(set) var playerOfCurrentTurn: ValueObservable<GameData.Player?>

    @MockBehaviorWrapeer(value: nil)
    private(set) var sideWithMoreDisks: ValueObservable<Disk?>

    @MockResponse<FlippedDiskCoordinates, [Coordinate]>
    var _flippedDiskCoordinates = []

    @MockResponse<CanPlace, Bool>
    var _canPlace = false

    @MockResponse<Disk, [Coordinate]>
    var _validMovekForDark = []

    @MockResponse<Disk, [Coordinate]>
    var _validMovekForLight = []

    @MockResponse<Void, Void>()
    var _waitForPlayer: Void

    @MockResponse<SetPlayer, Void>()
    var _setPlayer: Void

    @MockResponse<Void, Void>()
    var _newGame: Void

    @MockResponse<Void, Void>()
    var _startGame: Void

    @MockResponse<Coordinate, Void>()
    var _handleSelectedCoordinate: Void

    let cache = MockGameDataCache()

    func flippedDiskCoordinates(by disk: Disk, at coordinate: Coordinate) -> [Coordinate] {
        __flippedDiskCoordinates.respond(.init(disk: disk, coordinate: coordinate))
    }

    func canPlace(disk: Disk, at coordinate: Coordinate) -> Bool {
        __canPlace.respond(.init(disk: disk, coordinate: coordinate))
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
}

extension MockGameLogic {

    subscript<T>(dynamicMember keyPath: KeyPath<GameDataGettable, ValueObservable<T>>) -> ValueObservable<T> {
        cache[keyPath: keyPath]
    }

    func save() throws {
        try cache.save()
    }

    func setStatus(_ status: GameData.Status) {
        cache.setStatus(status)
    }

    func setDisk(_ disk: Disk?, at coordinate: Coordinate) {
        cache[coordinate] = disk
    }
}

extension MockGameLogic {
    struct FlippedDiskCoordinates: Equatable {
        let disk: Disk
        let coordinate: Coordinate
    }

    struct CanPlace: Equatable {
        let disk: Disk
        let coordinate: Coordinate
    }

    struct SetPlayer: Equatable {
        let disk: Disk
        let index: Int
    }
}
