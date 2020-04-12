import XCTest
@testable import ReversiLogic

class GameDataIOTests: XCTestCase {

    func test_save() throws {
        var response: String?

        try GameDataIO.save(
            turn: .dark,
            selectedSegumentIndexFor: { [0, 0][$0] },
            yRange: Const.range,
            xRange: Const.range,
            diskAt: { Const.initialData[$1][$0] },
            writeToFile: { output, _ in response = output }
        )

        XCTAssertEqual(response, Const.initialString)
    }

    func test_load() throws {
        let loader = MockLoader()

        try GameDataIO.loadGame(
            rawRepresentable: MockRepresentable.self,
            width: Const.count,
            height: Const.count,
            contentsOfFile: { _ in Const.initialString },
            setTurn: loader.setTurn,
            setSelectedSegmentIndexFor: loader.setSelectedSegmentIndexFor,
            setDisk: loader.setDisk,
            completion: {}
        )

        XCTAssertEqual(loader.turn, .dark)
        XCTAssertEqual(loader.selectedSideIndexes, [0, 1])
        XCTAssertEqual(loader.selectedValue, [0, 0])
        XCTAssertEqual(loader.board, Const.initialData)
    }
}

extension GameDataIOTests {

    private enum Const {
        static let count: Int = 8
        static let range = (0..<count)

        static let initialString = """
        x00
        --------
        --------
        --------
        ---ox---
        ---xo---
        --------
        --------
        --------

        """

        static let initialData: [[Disk?]] = [
            range.map { _ in nil },
            range.map { _ in nil },
            range.map { _ in nil },
            [nil, nil, nil, .light, .dark, nil, nil, nil],
            [nil, nil, nil, .dark, .light, nil, nil, nil],
            range.map { _ in nil },
            range.map { _ in nil },
            range.map { _ in nil },
        ]
    }

    private struct MockRepresentable: RawRepresentable {
        let rawValue: Int
    }

    private final class MockLoader {
        private(set) var turn: Disk?
        private(set) var selectedSideIndexes: [Int] = []
        private(set) var selectedValue: [Int] = []
        private(set) var board: [[Disk?]] = (0..<8).map { _ in (0..<8).map { _ in nil } }

        var setTurn: (Disk?) -> Void {
            return { [weak self] in
                self?.turn = $0
            }
        }
        var setSelectedSegmentIndexFor: (Int, Int) -> Void {
            return { [weak self] in
                self?.selectedSideIndexes += [$0]
                self?.selectedValue += [$1]
            }
        }
        var setDisk: (Disk?, Int, Int, Bool) -> Void {
            return { [weak self] disk, x, y, _ in
                self?.board[y][x] = disk
            }
        }
    }
}
