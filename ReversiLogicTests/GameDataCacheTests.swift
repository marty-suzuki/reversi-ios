import XCTest
@testable import ReversiLogic

final class GameDataCacheTests: XCTestCase {

    private var dependency: Dependency!

    override func setUp() {
        self.dependency = Dependency(cells: GameData.initial.cells)
    }

    func test_load() throws {
        let expectedCell = GameData.Cell(coordinate: .init(x: 0, y: 0), disk: nil)
        let expectedStatus = GameData.Status.gameOver
        let expectedPlayerDark = GameData.Player.computer
        let expectedPlayerLight = GameData.Player.computer

        let cache = dependency.testTarget
        dependency.loadGame = GameData(
            status: expectedStatus,
            playerDark: expectedPlayerDark,
            playerLight: expectedPlayerLight,
            cells: [[expectedCell]]
        )

        var isCompletionCalled = false
        try cache.load {
            isCompletionCalled = true
        }

        XCTAssertTrue(isCompletionCalled)
        XCTAssertEqual(cache.status.value, expectedStatus)
        XCTAssertEqual(cache.playerDark.value, expectedPlayerDark)
        XCTAssertEqual(cache.playerLight.value, expectedPlayerLight)
        XCTAssertEqual(cache.cells.value, [[expectedCell]])
    }

    func test_save() throws {
        let expectedCell = GameData.Cell(coordinate: .init(x: 1, y: 2), disk: .dark)
        let expectedPlayerDark: GameData.Player = .manual
        let expectedPlayerLight: GameData.Player = .computer
        let expectedStatus: GameData.Status = .turn(.light)

        self.dependency = Dependency(cells: [[expectedCell]])
        let cache = dependency.testTarget
        cache.setPlayerOfDark(expectedPlayerDark)
        cache.setPlayerOfLight(expectedPlayerLight)
        cache.setStatus(expectedStatus)

        try cache.save()

        let saveGame = dependency.$saveGame
        XCTAssertEqual(saveGame.calledCount, 1)

        let expected = GameData(status: expectedStatus,
                                playerDark: expectedPlayerDark,
                                playerLight: expectedPlayerLight,
                                cells: [[expectedCell]])
        XCTAssertEqual(saveGame.parameters, [expected])
    }

    func test_rest() {
        self.dependency = Dependency(cells: [])
        let cache = dependency.testTarget
        cache.setStatus(.gameOver)
        cache.setPlayerOfDark(.computer)
        cache.setPlayerOfLight(.computer)

        cache.reset()

        XCTAssertEqual(cache.cells.value, GameData.initial.cells)
        XCTAssertEqual(cache.status.value, GameData.initial.status)
        XCTAssertEqual(cache.playerDark.value, GameData.initial.playerDark)
        XCTAssertEqual(cache.playerLight.value, GameData.initial.playerLight)
    }
}

extension GameDataCacheTests {

    final class Dependency {

        @MockResponse<GameData, Void>()
        var saveGame: Void

        @MockResponse<Void, GameData>
        var loadGame: GameData

        private(set) lazy var testTarget = GameDataCache(
            loadGame: { [weak self] _, completion in
                guard let me = self else {
                    return
                }
                completion(me._loadGame.respond())
            },
            saveGame: { [weak self] data, _ in self?._saveGame.respond(data) },
            cells: loadGame.cells
        )

        init(cells: [[GameData.Cell]]) {
            self.loadGame = GameData(status: .turn(.dark),
                                     playerDark: GameData.initial.playerDark,
                                     playerLight: GameData.initial.playerLight,
                                     cells: cells)
        }
    }
}
