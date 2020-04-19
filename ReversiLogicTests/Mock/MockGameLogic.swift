@testable import ReversiLogic

struct MockGameLogicFactory: GameLogicFactoryProtocol {

    private let logic: MockGameLogic

    init(logic: MockGameLogic) {
        self.logic = logic
    }

    func make(cache: GameDataGettable) -> GameLogicProtocol {
        logic
    }
}

final class MockGameLogic: GameLogicProtocol {

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
}
