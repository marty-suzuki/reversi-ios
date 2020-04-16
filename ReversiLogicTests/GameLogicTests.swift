import XCTest
@testable import ReversiLogic

final class GameLogicTests: XCTestCase {

    func test_count() {
        let disk = Disk.dark
        let y = 2
        let x = 3
        let cells: [[GameData.Board.Cell]] = (0..<y).map { y in
            (0..<x).map { x in
                GameData.Board.Cell(x: x, y: y, disk: disk)
            }
        }

        let count = GameLogic.count(of: .dark, from: cells)
        XCTAssertEqual(count, x * y)
    }

    func test_sideWithMoreDisks_darkの方が多い() {
        let cells = [
            GameData.Board.Cell(x: 0, y: 0, disk: .dark),
            GameData.Board.Cell(x: 1, y: 0, disk: .dark),
            GameData.Board.Cell(x: 2, y: 0, disk: .light)
        ]

        let result = GameLogic.sideWithMoreDisks(from: [cells])
        XCTAssertEqual(result, .dark)
    }

    func test_sideWithMoreDisks_lightの方が多い() {
        let cells = [
            GameData.Board.Cell(x: 0, y: 0, disk: .dark),
            GameData.Board.Cell(x: 1, y: 0, disk: .light),
            GameData.Board.Cell(x: 2, y: 0, disk: .light)
        ]

        let result = GameLogic.sideWithMoreDisks(from: [cells])
        XCTAssertEqual(result, .light)
    }

    func test_sideWithMoreDisks_darkとlightが同じ数() {
        let cells = [
            GameData.Board.Cell(x: 0, y: 0, disk: .dark),
            GameData.Board.Cell(x: 1, y: 0, disk: .light)
        ]

        let result = GameLogic.sideWithMoreDisks(from: [cells])
        XCTAssertNil(result)
    }

    func test_flippedDiskCoordinatesByPlacingDisk_diskが有効な位置の場合() throws {
        let board: [[Disk?]] = [
            [nil, nil,    nil,   nil,   nil],
            [nil, .light, .dark, nil,   nil],
            [nil, .light, .dark, .dark, nil],
            [nil, .light, nil,   nil,   nil]
        ]
        let cells = board.enumerated().map { y, rows in
            rows.enumerated().map { x, disk in
                GameData.Board.Cell(x: x, y: y, disk: disk)
            }
        }

        // case1
        do {
            let coordinates = GameLogic.flippedDiskCoordinates(
                from: cells,
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
            let coordinates = GameLogic.flippedDiskCoordinates(
                from: cells,
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
        let cells = board.enumerated().map { y, rows in
            rows.enumerated().map { x, disk in
                GameData.Board.Cell(x: x, y: y, disk: disk)
            }
        }

        // case1
        do {
            let coordinates = GameLogic.flippedDiskCoordinates(
                from: cells,
                by: .dark,
                at: Coordinate(x: 3, y: 1)
            )

            XCTAssertTrue(coordinates.isEmpty)
        }

        // case2
        do {
            let coordinates = GameLogic.flippedDiskCoordinates(
                from: cells,
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
        let cells = board.enumerated().map { y, rows in
            rows.enumerated().map { x, disk in
                GameData.Board.Cell(x: x, y: y, disk: disk)
            }
        }

        let coordinates = GameLogic.validMoves(for: .dark, from: cells)

        let expected = [
            Coordinate(x: 0, y: 0),
            Coordinate(x: 0, y: 1),
            Coordinate(x: 0, y: 2),
            Coordinate(x: 0, y: 3)
        ]
        XCTAssertEqual(coordinates, expected)
    }
}
