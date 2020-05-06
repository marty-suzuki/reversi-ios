import XCTest
@testable import ReversiLogic

final class FlippedDiskCoordinatesTests: XCTestCase {
    private var dependency: Dependency!

    override func setUp() {
        self.dependency = Dependency()
    }

    func test_callAsFunction_coordinateに対応したcellがない() {
        let coordinate = Coordinate(x: 0, y: 0)
        let disk = Disk.dark
        let coordinates = dependency.testTarget(by: disk, at: coordinate)
        XCTAssertTrue(coordinates.isEmpty)
    }

    func test_callAsFunction_反転できるcellが存在する() {
        let store = dependency.store
        let board: [[Disk?]] = [
                [nil, nil, nil, nil],
                [nil, .dark, .light, nil],
                [nil, nil, nil, nil],
            ]

        let cells: [[GameData.Cell]] = board
            .enumerated()
            .map { y, rows -> [GameData.Cell] in
                rows.enumerated().map { x, disk in
                    GameData.Cell(coordinate: .init(x: x, y: y), disk: disk)
                }
            }

        store.$cells.accept(cells)
        let coordinates = dependency.testTarget(by: .light, at: .init(x: 0, y: 1))
        XCTAssertEqual(coordinates, [.init(x: 1, y: 1)])
    }
}

extension FlippedDiskCoordinatesTests {
    private final class Dependency {
        let store = MockGameStore()
        let testTarget: FlippedDiskCoordinates

        init() {
            self.testTarget = FlippedDiskCoordinates(store: store)
        }
    }
}
