import TestModule
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

        let result = Watcher(validMoves(for: disk).asObservable())
        flippedDiskCoordinates._callAsFunction.onNext(coordinates)
        flippedDiskCoordinates._callAsFunction.onNext(coordinates)
        flippedDiskCoordinates._callAsFunction.onNext(coordinates)

        XCTAssertEqual(result.parameters, [coordinates])

        XCTAssertEqual(flippedDiskCoordinates.$_callAsFunction.calledCount, 3)

        let expected = coordinates.map { coordinate in
            MockFlippedDiskCoordinates.Parameters(disk: disk, coordinate: coordinate)
        }
        XCTAssertEqual(flippedDiskCoordinates.$_callAsFunction.parameters, expected)
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
