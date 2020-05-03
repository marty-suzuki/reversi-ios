@testable import ReversiLogic

final class MockFlippedDiskCoordinates: FlippedDiskCoordinatesProtocol {

    @MockResponse<Parameters, [Coordinate]>
    var callAsFunctionResponse: [Coordinate] = []

    func callAsFunction(by disk: Disk, at coordinate: Coordinate) -> [Coordinate] {
        _callAsFunctionResponse.respond(.init(disk: disk, coordinate: coordinate))
    }

    struct Parameters: Equatable {
        let disk: Disk
        let coordinate: Coordinate
    }
}
