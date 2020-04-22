import RxRelay
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

        let gameData = BehaviorRelay<GameData?>(value: nil)
        let disposable = cache.load()
            .asObservable()
            .bind(to: gameData)
        defer { disposable.dispose() }

        let response = try XCTUnwrap(gameData.value)
        XCTAssertEqual(response.status, expectedStatus)
        XCTAssertEqual(response.playerDark, expectedPlayerDark)
        XCTAssertEqual(response.playerLight, expectedPlayerLight)
        XCTAssertEqual(response.cells, [[expectedCell]])
    }

    func test_save() throws {
        let expectedCell = GameData.Cell(coordinate: .init(x: 1, y: 2), disk: .dark)
        let expectedPlayerDark: GameData.Player = .manual
        let expectedPlayerLight: GameData.Player = .computer
        let expectedStatus: GameData.Status = .turn(.light)

        self.dependency = Dependency(cells: [[expectedCell]])
        let cache = dependency.testTarget
        let expected = GameData(status: expectedStatus,
                                playerDark: expectedPlayerDark,
                                playerLight: expectedPlayerLight,
                                cells: [[expectedCell]])

        let save = BehaviorRelay<Void?>(value: nil)
        let disposable = cache.save(data: expected)
            .asObservable()
            .bind(to: save)
        defer { disposable.dispose() }

        let saveGame = dependency.$saveGame
        XCTAssertNotNil(save.value)
        XCTAssertEqual(saveGame.calledCount, 1)
        XCTAssertEqual(saveGame.parameters, [expected])
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
            saveGame: { [weak self] data, _ in self?._saveGame.respond(data) }
        )

        init(cells: [[GameData.Cell]]) {
            self.loadGame = GameData(status: .turn(.dark),
                                     playerDark: GameData.initial.playerDark,
                                     playerLight: GameData.initial.playerLight,
                                     cells: cells)
        }
    }
}
