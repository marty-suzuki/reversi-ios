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

    @CountableProperty
    var playerCancellers: [Disk : Canceller] = [:]

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
}

extension MockGameLogic {

    subscript<T>(dynamicMember keyPath: KeyPath<GameDataGettable, ValueObservable<T>>) -> ValueObservable<T> {
        cache[keyPath: keyPath]
    }

    subscript(coordinate: Coordinate) -> Disk? {
        get { cache[coordinate] }
        set { cache[coordinate] = newValue }
    }

    func load() -> Single<Void> {
        cache.load()
    }

    func save() throws {
        try cache.save()
    }

    func reset() {
        cache.reset()
    }

    func setStatus(_ status: GameData.Status) {
        cache.setStatus(status)
    }

    func setPlayerOfDark(_ player: GameData.Player) {
        cache.setPlayerOfDark(player)
    }

    func setPlayerOfLight(_ player: GameData.Player) {
        cache.setPlayerOfLight(player)
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
