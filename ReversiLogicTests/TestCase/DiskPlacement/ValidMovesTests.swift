import XCTest
@testable import ReversiLogic

final class ValidMovesTests: XCTestCase {
    private var dependency: Dependency!

    override func setUp() {
        self.dependency = Dependency()
    }

    func test_callAsFunction() {
        let flippedDiskCoordinates = dependency.flippedDiskCoordinates
        let store = dependency.store
        let validMoves = dependency.testTarget

        let disk = Disk.dark
        let coordinates = [
            Coordinate(x: 0, y: 0),
            Coordinate(x: 1, y: 0),
            Coordinate(x: 2, y: 0)
        ]
        store.$cells.accept([coordinates.map { GameData.Cell(coordinate: $0, disk: disk) }])
        flippedDiskCoordinates.callAsFunctionResponse = coordinates

        let result = validMoves(for: disk)
        XCTAssertEqual(result, coordinates)

        XCTAssertEqual(flippedDiskCoordinates.$callAsFunctionResponse.calledCount, 3)

        let expected = coordinates.map { coordinate in
            MockFlippedDiskCoordinates.Parameters(disk: disk, coordinate: coordinate)
        }
        XCTAssertEqual(flippedDiskCoordinates.$callAsFunctionResponse.parameters, expected)
    }
}

extension ValidMovesTests {
    private final class Dependency {
        let testTarget: ValidMoves

        let flippedDiskCoordinates = MockFlippedDiskCoordinates()
        let store = MockGameStore()

        init() {
            self.testTarget = ValidMoves(flippedDiskCoordinates: flippedDiskCoordinates,
                                         store: store)
        }
    }
}
