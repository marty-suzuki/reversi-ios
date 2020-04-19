import XCTest
@testable import ReversiLogic

final class GameDataCacheTests: XCTestCase {

    private var dependency: Dependency!

    override func setUp() {
        self.dependency = Dependency(playerDark: GameData.initial.playerDark,
                                     playerLight: GameData.initial.playerLight,
                                     cells: GameData.initial.cells)
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
        XCTAssertEqual(cache.status, expectedStatus)
        XCTAssertEqual(cache[.dark], expectedPlayerDark)
        XCTAssertEqual(cache[.light], expectedPlayerLight)
        XCTAssertEqual(cache.cells, [[expectedCell]])
    }

    func test_save() throws {
        let expectedCell = GameData.Cell(coordinate: .init(x: 1, y: 2), disk: .dark)
        let expectedPlayerDark: GameData.Player = .manual
        let expectedPlayerLight: GameData.Player = .computer
        let expectedStatus: GameData.Status = .turn(.light)

        self.dependency = Dependency(playerDark: .manual,
                                     playerLight: .manual,
                                     cells: [[expectedCell]])
        let cache = dependency.testTarget
        cache[.dark] = expectedPlayerDark
        cache[.light] = expectedPlayerLight
        cache.status = expectedStatus

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
        self.dependency = Dependency(playerDark: .manual,
                                     playerLight: .manual,
                                     cells: [])
        let cache = dependency.testTarget
        cache.status = .gameOver
        cache[.dark] = .computer
        cache[.light] = .computer

        cache.reset()

        XCTAssertEqual(cache.cells, GameData.initial.cells)
        XCTAssertEqual(cache.status, GameData.initial.status)
        XCTAssertEqual(cache[.dark], GameData.initial.playerDark)
        XCTAssertEqual(cache[.light], GameData.initial.playerLight)
    }

    func test_subscript_getPlayer() {
        self.dependency = Dependency(playerDark: .manual,
                                     playerLight: .computer,
                                     cells: [])
        let cache = dependency.testTarget
        XCTAssertEqual(cache[.dark], .manual)
        XCTAssertEqual(cache[.light], .computer)
    }

    func test_subscript_setPlayer() {
        self.dependency = Dependency(playerDark: .manual,
                                     playerLight: .computer,
                                     cells: [])
        let cache = dependency.testTarget
        cache[.dark] = .computer
        cache[.light] = .manual
        XCTAssertEqual(cache.playerDark, .computer)
        XCTAssertEqual(cache.playerLight, .manual)
    }

    func test_playerOfCurrentTurn() {
        let cache = dependency.testTarget

        cache.status = .gameOver
        XCTAssertNil(cache.playerOfCurrentTurn)

        cache.status = .turn(.dark)
        cache[.dark] = .computer
        XCTAssertEqual(cache.playerOfCurrentTurn, .computer)

        cache.status = .turn(.light)
        cache[.light] = .computer
        XCTAssertEqual(cache.playerOfCurrentTurn, .computer)
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
            playerDark: playerDark,
            playerLight: playerLight,
            cells: cells
        )

        private let playerDark: GameData.Player
        private let playerLight: GameData.Player
        private let cells: [[GameData.Cell]]

        init(playerDark: GameData.Player,
             playerLight: GameData.Player,
             cells: [[GameData.Cell]]) {
            self.playerDark = playerDark
            self.playerLight = playerLight
            self.cells = cells
            self.loadGame = GameData(status: .turn(.dark),
                                     playerDark: playerDark,
                                     playerLight: playerLight,
                                     cells: cells)
        }
    }
}
