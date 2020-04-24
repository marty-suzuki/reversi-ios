@testable import ReversiLogic

final class MockFlippedDiskCoordinates: FlippedDiskCoordinatesProtocol {

    @MockResponse<ExecuteParameters, [Coordinate]>
    var _execute: [Coordinate] = []

    func execute(disk: Disk, at coordinate: Coordinate, cells: [[GameData.Cell]]) -> [Coordinate] {
        __execute.respond(.init(disk: disk, coordinate: coordinate, cells: cells))
    }

    struct ExecuteParameters: Equatable {
        let disk: Disk
        let coordinate: Coordinate
        let cells: [[GameData.Cell]]
    }
}
