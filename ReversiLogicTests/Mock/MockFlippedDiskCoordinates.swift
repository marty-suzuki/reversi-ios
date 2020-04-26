@testable import ReversiLogic

final class MockFlippedDiskCoordinates: FlippedDiskCoordinatesProtocol {

    @MockResponse<ExecuteParameters, [Coordinate]>
    var callAsFunctionResponse: [Coordinate] = []

    func callAsFunction(by disk: Disk, at coordinate: Coordinate, cells: [[GameData.Cell]]) -> [Coordinate] {
        _callAsFunctionResponse.respond(.init(disk: disk, coordinate: coordinate, cells: cells))
    }

    struct ExecuteParameters: Equatable {
        let disk: Disk
        let coordinate: Coordinate
        let cells: [[GameData.Cell]]
    }
}
