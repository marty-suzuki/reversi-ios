import XCTest
@testable import ReversiLogic

class GameDataIOTests: XCTestCase {

    func test_save() throws {
        var response: String?
        try GameDataIO.save(
            data: GameData.initial,
            writeToFile:  { output, _ in response = output }
        )

        XCTAssertEqual(response, Const.initialString)
    }

    func test_load() throws {
        var gameData: GameData?
        try GameDataIO.loadGame(
            contentsOfFile:  { _ in Const.initialString },
            completion: { gameData = $0 }
        )

        XCTAssertEqual(gameData, GameData.initial)
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
    }
}
