@testable import ReversiLogic

struct MockGameLogicFactory: GameLogicFactoryProtocol {

    private let logic: MockGameLogic

    init(logic: MockGameLogic) {
        self.logic = logic
    }

    func make(cache: GameDataCellGettable & GemeDataDiskGettable) -> GameLogicProtocol {
        logic
    }
}

final class MockGameLogic: GameLogicProtocol {

    @MockResponse<Disk, Int>
    var _countOfDark = 0

    @MockResponse<Disk, Int>
    var _countOfLight = 0

    @MockResponse<Void, Disk?>
    var _sideWithMoreDisks = nil

    @MockResponse<FlippedDiskCoordinates, [Coordinate]>
    var _flippedDiskCoordinates = []

    @MockResponse<CanPlace, Bool>
    var _canPlace = false

    @MockResponse<Disk, [Coordinate]>
    var _validMovekForDark = []

    @MockResponse<Disk, [Coordinate]>
    var _validMovekForLight = []

    func count(of disk: Disk) -> Int {
        switch disk {
        case .dark:
            return __countOfDark.respond(disk)
        case .light:
            return __countOfLight.respond(disk)
        }
    }

    func sideWithMoreDisks() -> Disk? {
        __sideWithMoreDisks.respond()
    }

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
