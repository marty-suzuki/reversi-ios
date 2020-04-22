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

    func test_countOfDark() {
        dependency.dispatcher.setCells.accept([[
            GameData.Cell(coordinate: Coordinate(x: 0, y: 0), disk: .dark)
        ]])

        let countOfDark = dependency.testTarget.countOfDark.value
        XCTAssertEqual(countOfDark, 1)
    }

    func test_countOfLight() {
        dependency.dispatcher.setCells.accept([[
            GameData.Cell(coordinate: Coordinate(x: 0, y: 0), disk: .light)
        ]])

        let countOfDark = dependency.testTarget.countOfLight.value
        XCTAssertEqual(countOfDark, 1)
    }

    func test_playerOfCurrentTurn() {
        let store = dependency.testTarget
        let dispatcher = dependency.dispatcher

        dispatcher.setStatus.accept(.gameOver)
        XCTAssertNil(store.playerOfCurrentTurn.value)

        dispatcher.setStatus.accept(.turn(.dark))
        dispatcher.setPlayerOfDark.accept(.computer)
        XCTAssertEqual(store.playerOfCurrentTurn.value, .computer)

        dispatcher.setStatus.accept(.turn(.light))
        dispatcher.setPlayerOfLight.accept(.computer)
        XCTAssertEqual(store.playerOfCurrentTurn.value, .computer)
    }

    func test_sideWithMoreDisks_darkの方が多い() {
        dependency.dispatcher.setCells.accept([
            [
                GameData.Cell(coordinate: .init(x: 0, y: 0), disk: .dark),
                GameData.Cell(coordinate: .init(x: 1, y: 0), disk: .dark),
                GameData.Cell(coordinate: .init(x: 2, y: 0), disk: .light)
            ]
        ])

        let result = dependency.testTarget.sideWithMoreDisks.value
        XCTAssertEqual(result, .dark)
    }

    func test_sideWithMoreDisks_lightの方が多い() {
        dependency.dispatcher.setCells.accept([
            [
                GameData.Cell(coordinate: .init(x: 0, y: 0), disk: .dark),
                GameData.Cell(coordinate: .init(x: 1, y: 0), disk: .light),
                GameData.Cell(coordinate: .init(x: 2, y: 0), disk: .light)
            ]
        ])

        let result = dependency.testTarget.sideWithMoreDisks.value
        XCTAssertEqual(result, .light)
    }

    func test_sideWithMoreDisks_darkとlightが同じ数() {
        dependency.dispatcher.setCells.accept([
            [
                GameData.Cell(coordinate: .init(x: 0, y: 0), disk: .dark),
                GameData.Cell(coordinate: .init(x: 1, y: 0), disk: .light)
            ]
        ])

        let result = dependency.testTarget.sideWithMoreDisks.value
        XCTAssertNil(result)
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
