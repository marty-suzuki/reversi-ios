import RxSwift
import XCTest
@testable import ReversiLogic

final class GameLogicTests: XCTestCase {

    private var dependency: Dependency!

    override func setUp() {
        self.dependency = Dependency()
    }

    func test_countOfDark() {
        let disk = Disk.dark
        let y = 2
        let x = 3

        dependency.cache.$cells.accept((0..<y).map { y in
            (0..<x).map { x in
                GameData.Cell(coordinate: .init(x: x, y: y), disk: disk)
            }
        })

        let count = dependency.testTarget.countOfDark.value
        XCTAssertEqual(count, x * y)
    }

    func test_countOfLight() {
        let disk = Disk.light
        let y = 2
        let x = 3

        dependency.cache.$cells.accept((0..<y).map { y in
            (0..<x).map { x in
                GameData.Cell(coordinate: .init(x: x, y: y), disk: disk)
            }
        })

        let count = dependency.testTarget.countOfLight.value
        XCTAssertEqual(count, x * y)
    }

    func test_playerOfCurrentTurn() {
        let logic = dependency.testTarget
        let cache = dependency.cache

        cache.$status.accept(.gameOver)
        XCTAssertNil(logic.playerOfCurrentTurn.value)

        cache.$status.accept(.turn(.dark))
        cache.$playerDark.accept(.computer)
        XCTAssertEqual(logic.playerOfCurrentTurn.value, .computer)

        cache.$status.accept(.turn(.light))
        cache.$playerLight.accept(.computer)
        XCTAssertEqual(logic.playerOfCurrentTurn.value, .computer)
    }

    func test_sideWithMoreDisks_darkの方が多い() {
        dependency.cache.$cells.accept([
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
        dependency.cache.$cells.accept([
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
        dependency.cache.$cells.accept([
            [
                GameData.Cell(coordinate: .init(x: 0, y: 0), disk: .dark),
                GameData.Cell(coordinate: .init(x: 1, y: 0), disk: .light)
            ]
        ])

        let result = dependency.testTarget.sideWithMoreDisks.value
        XCTAssertNil(result)
    }

    func test_flippedDiskCoordinatesByPlacingDisk_diskが有効な位置の場合() throws {
        let board: [[Disk?]] = [
            [nil, nil,    nil,   nil,   nil],
            [nil, .light, .dark, nil,   nil],
            [nil, .light, .dark, .dark, nil],
            [nil, .light, nil,   nil,   nil]
        ]
        dependency.cache.$cells.accept(board.enumerated().map { y, rows in
            rows.enumerated().map { x, disk in
                GameData.Cell(coordinate: .init(x: x, y: y), disk: disk)
            }
        })
        let logic = dependency.testTarget

        // case1
        do {
            let coordinates = logic.flippedDiskCoordinates(
                by: .light,
                at: Coordinate(x: 3, y: 1)
            )

            let expected = [
                Coordinate(x: 2, y: 1),
                Coordinate(x: 2, y: 2)
            ]
            XCTAssertEqual(coordinates, expected)
        }

        // case2
        do {
            let coordinates = logic.flippedDiskCoordinates(
                by: .light,
                at: Coordinate(x: 4, y: 2)
            )

            let expected = [
                Coordinate(x: 3, y: 2),
                Coordinate(x: 2, y: 2)
            ]
            XCTAssertEqual(coordinates, expected)
        }
    }

    func test_flippedDiskCoordinatesByPlacingDisk_diskが無効な位置の場合() {
        let board: [[Disk?]] = [
            [nil, nil,    nil,   nil,   nil],
            [nil, .light, .dark, nil,   nil],
            [nil, .light, .dark, .dark, nil],
            [nil, .light, nil,   nil,   nil]
        ]
        dependency.cache.$cells.accept(board.enumerated().map { y, rows in
            rows.enumerated().map { x, disk in
                GameData.Cell(coordinate: .init(x: x, y: y), disk: disk)
            }
        })
        let logic = dependency.testTarget

        // case1
        do {
            let coordinates = logic.flippedDiskCoordinates(
                by: .dark,
                at: Coordinate(x: 3, y: 1)
            )

            XCTAssertTrue(coordinates.isEmpty)
        }

        // case2
        do {
            let coordinates = logic.flippedDiskCoordinates(
                by: .light,
                at: Coordinate(x: 2, y: 0)
            )

            XCTAssertTrue(coordinates.isEmpty)
        }
    }

    func test_validMoves() throws {
        let board: [[Disk?]] = [
            [nil, nil,    nil,   nil,   nil],
            [nil, .light, .dark, nil,   nil],
            [nil, .light, .dark, .dark, nil],
            [nil, .light, nil,   nil,   nil]
        ]
        dependency.cache.$cells.accept(board.enumerated().map { y, rows in
            rows.enumerated().map { x, disk in
                GameData.Cell(coordinate: .init(x: x, y: y), disk: disk)
            }
        })

        let coordinates = dependency.testTarget.validMoves(for: .dark)

        let expected = [
            Coordinate(x: 0, y: 0),
            Coordinate(x: 0, y: 1),
            Coordinate(x: 0, y: 2),
            Coordinate(x: 0, y: 3)
        ]
        XCTAssertEqual(coordinates, expected)
    }

    func test_waitForPlayer_turnがdarkで_playerDarkがmanualの場合() {
        let viewModel = dependency.testTarget
        let cache = dependency.cache
        let turn = Disk.dark
        cache.$status.accept(.turn(turn))
        cache.$playerDark.accept(.manual)

        viewModel.waitForPlayer()

        let playTurnOfComputer = dependency.$playTurnOfComputer
        XCTAssertEqual(playTurnOfComputer.calledCount, 0)
    }

    func test_waitForPlayer_turnがlightで_playerLightがcomputerの場合() {
        let viewModel = dependency.testTarget
        let cache = dependency.cache
        let turn = Disk.light
        cache.$status.accept(.turn(turn))
        cache.$playerLight.accept(.computer)

        viewModel.waitForPlayer()

        let playTurnOfComputer = dependency.$playTurnOfComputer
        XCTAssertEqual(playTurnOfComputer.calledCount, 1)
    }

    func test_waitForPlayer_statusがgameOverの場合() {
        let viewModel = dependency.testTarget
        let cache = dependency.cache
        cache.$status.accept(.gameOver)
        cache.$playerDark.accept(.computer)
        cache.$playerLight.accept(.computer)

        viewModel.waitForPlayer()

        let playTurnOfComputer = dependency.$playTurnOfComputer
        XCTAssertEqual(playTurnOfComputer.calledCount, 0)
    }
}

extension GameLogicTests {

    private final class Dependency {

        @MockResponse<Void, Void>()
        var playTurnOfComputer: Void

        private(set) lazy var testTarget = GameLogic(cache: cache)
        let cache = MockGameDataCache()

        private let disposeBag = DisposeBag()

        init() {
            testTarget.playTurnOfComputer
                .subscribe(onNext: { [weak self] in self?._playTurnOfComputer.respond() })
                .disposed(by: disposeBag)
        }
    }
}
