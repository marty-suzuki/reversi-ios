@testable import ReversiLogic

public struct MockFlippedDiskCoordinatesFactory: FlippedDiskCoordinatesFactoryProtocol {

    let flippedDiskCoordinates: MockFlippedDiskCoordinates

    public func make(store: GameStoreProtocol) -> FlippedDiskCoordinatesProtocol {
        flippedDiskCoordinates
    }
}

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
