import XCTest
@testable import ReversiLogic

final class GameStoreTests: XCTestCase {

    private var dependency: Dependency!

    override func setUp() {
        self.dependency = Dependency()
    }

    func test_setDiskAtCoordinate() {
        let coordinate = Coordinate(x: 0, y: 0)
        dependency.dispatcher.setCells.accept([[
            GameData.Cell(coordinate: coordinate, disk: .dark)
        ]])

        let disk = Disk.light
        dependency.dispatcher.setDiskAtCoordinate.accept((disk, coordinate))

        let cells = dependency.testTarget.cells.value
        XCTAssertEqual(cells, [[GameData.Cell(coordinate: coordinate, disk: disk)]])
    }

    func test_diskAtCooordinate() {
        let disk = Disk.light
        let coordinate = Coordinate(x: 0, y: 0)
        dependency.dispatcher.setCells.accept([[
            GameData.Cell(coordinate: coordinate, disk: disk)
        ]])

        let response = dependency.testTarget.disk(at: coordinate)
        XCTAssertEqual(response, disk)
    }
}

extension GameStoreTests {

    private final class Dependency {
        let testTarget: GameStore
        let dispatcher = GameDispatcher()
        init() {
            self.testTarget = GameStore(dispatcher: dispatcher)
        }
    }
}
