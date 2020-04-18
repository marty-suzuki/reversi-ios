@testable import ReversiLogic

enum MockGameLogicFactory: GameLogicFactoryProtocol {
    static func make(cache: GameDataCellGettable & GemeDataDiskGettable) -> GameLogicProtocol {
        MockGameLogic()
    }
}

final class MockGameLogic: GameLogicProtocol {

    @MockResponse<Disk, Int>
    var _count = 0

    @MockResponse<Void, Disk?>
    var _sideWithMoreDisks = nil

    @MockResponse<FlippedDiskCoordinates, [Coordinate]>
    var _flippedDiskCoordinates = []

    @MockResponse<CanPlace, Bool>
    var _canPlace = false

    @MockResponse<Disk, [Coordinate]>
    var _validMoves = []

    func count(of disk: Disk) -> Int {
        __count.respond(disk)
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
        __validMoves.respond(disk)
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
