import XCTest
@testable import ReversiLogic

final class GameDataCacheTests: XCTestCase {

    private var dependency: Dependency!

    override func setUp() {
        self.dependency = Dependency(board: .initial())
    }

    func test_load() throws {
        let expectedCell = GameData.Board.Cell(x: 0, y: 0, disk: nil)
        let expectedStatus = GameData.Status.gameOver
        let expectedPlayerDark = GameData.Player.computer
        let expectedPlayerLight = GameData.Player.computer

        let cache = dependency.testTarget
        dependency.loadGame = GameData(
            status: expectedStatus,
            playerDark: expectedPlayerDark,
            playerLight: expectedPlayerLight,
            board: .init(cells: [[expectedCell]])
        )

        var isCompletionCalled = false
        try cache.load {
            isCompletionCalled = true
        }

        XCTAssertTrue(isCompletionCalled)
        XCTAssertEqual(cache.status, expectedStatus)
        XCTAssertEqual(cache.playerDark, expectedPlayerDark)
        XCTAssertEqual(cache.playerLight, expectedPlayerLight)
        XCTAssertEqual(cache.cells, [[expectedCell]])
    }

    func test_save() throws {
        let expectedCell = GameData.Board.Cell(
            x: 1,
            y: 2,
            disk: .dark
        )
        let expectedPlayerDark: GameData.Player = .manual
        let expectedPlayerLight: GameData.Player = .computer
        let expectedStatus: GameData.Status = .turn(.light)

        self.dependency = Dependency(board: .init(cells: [[expectedCell]]))
        let cache = dependency.testTarget
        cache.playerDark = expectedPlayerDark
        cache.playerLight = expectedPlayerLight
        cache.status = expectedStatus

        try cache.save()

        let saveGame = dependency.$saveGame
        XCTAssertEqual(saveGame.calledCount, 1)

        let expected = GameData(status: expectedStatus,
                                playerDark: expectedPlayerDark,
                                playerLight: expectedPlayerLight,
                                board: .init(cells: [[expectedCell]]))
        XCTAssertEqual(saveGame.parameters, [expected])
    }

    func test_rest() {
        self.dependency = Dependency(board: .init(cells: []))
        let cache = dependency.testTarget
        cache.status = .gameOver
        cache.playerDark = .computer
        cache.playerLight = .computer

        cache.reset()

        XCTAssertEqual(cache.cells, GameData.Board.initial().cells)
        XCTAssertEqual(cache.status, .turn(.dark))
        XCTAssertEqual(cache.playerDark, .manual)
        XCTAssertEqual(cache.playerLight, .manual)
    }
}

extension GameDataCacheTests {

    final class Dependency {

        @MockResponse<GameData, Void>()
        var saveGame: Void

        @MockResponse<Void, GameData>
        var loadGame: GameData

        private(set) lazy var testTarget = GameDataCache.init(
            loadGame: { [weak self] _, completion in
                guard let me = self else {
                    return
                }
                completion(me._loadGame.respond())
            },
            saveGame: { [weak self] data, _ in self?._saveGame.respond(data) },
            cells: cells
        )

        private let cells: [[GameData.Board.Cell]]

        init(board: GameData.Board) {
            self.cells = board.cells
            self.loadGame = GameData(status: .turn(.dark),
                                     playerDark: .manual,
                                     playerLight: .manual,
                                     board: board)
        }
    }
}
