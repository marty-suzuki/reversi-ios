import XCTest
@testable import ReversiLogic

final class ReversiViewModelTests: XCTestCase {

    private var dependency: Dependency!

    override func setUp() {
        self.dependency = Dependency(board: .initial())
    }

    func test_waitForPlayer_turnがdarkで_selectedSegmentIndexが0の場合() {
        let viewModel = dependency.testTarget
        let turn = Disk.dark

        viewModel.turn = turn
        dependency._selectedSegmentIndexFor = 0

        viewModel.waitForPlayer()

        let selectedSegmentIndexFor = dependency.$_selectedSegmentIndexFor
        let playTurnOfComputer = dependency.$_playTurnOfComputer
        XCTAssertEqual(selectedSegmentIndexFor.calledCount, 1)
        XCTAssertEqual(selectedSegmentIndexFor.parameters, [turn.index])
        XCTAssertEqual(playTurnOfComputer.calledCount, 0)
    }

    func test_waitForPlayer_turnがlightで_selectedSegmentIndexが1の場合() {
        let viewModel = dependency.testTarget
        let turn = Disk.light

        viewModel.turn = turn
        dependency._selectedSegmentIndexFor = 1

        viewModel.waitForPlayer()

        let selectedSegmentIndexFor = dependency.$_selectedSegmentIndexFor
        let playTurnOfComputer = dependency.$_playTurnOfComputer
        XCTAssertEqual(selectedSegmentIndexFor.calledCount, 1)
        XCTAssertEqual(selectedSegmentIndexFor.parameters, [turn.index])
        XCTAssertEqual(playTurnOfComputer.calledCount, 1)
    }

    func test_waitForPlayer_turnがnilの場合() {
        let viewModel = dependency.testTarget

        viewModel.turn = nil
        viewModel.waitForPlayer()

        let selectedSegmentIndexFor = dependency.$_selectedSegmentIndexFor
        let playTurnOfComputer = dependency.$_playTurnOfComputer
        XCTAssertEqual(selectedSegmentIndexFor.calledCount, 0)
        XCTAssertEqual(selectedSegmentIndexFor.parameters, [])
        XCTAssertEqual(playTurnOfComputer.calledCount, 0)
    }

    func test_viewDidAppear_selectedSegmentIndexForが2回呼ばれることはない() {
        let viewModel = dependency.testTarget
        let turn = Disk.dark

        viewModel.turn = turn
        viewModel.viewDidAppear()

        let selectedSegmentIndexFor = dependency.$_selectedSegmentIndexFor
        XCTAssertEqual(selectedSegmentIndexFor.calledCount, 1)
        XCTAssertEqual(selectedSegmentIndexFor.parameters, [turn.index])

        viewModel.viewDidAppear()
        XCTAssertEqual(selectedSegmentIndexFor.calledCount, 1)
        XCTAssertEqual(selectedSegmentIndexFor.parameters, [turn.index])
    }

    func test_newGame() {
        let viewModel = dependency.testTarget
        viewModel.turn = nil

        viewModel.newGame()

        let reset = dependency.$reset
        XCTAssertEqual(reset.calledCount, 1)
        XCTAssertEqual(viewModel.turn, .dark)

        let setPlayerDarkSelectedIndex = dependency.$setPlayerDarkSelectedIndex
        XCTAssertEqual(setPlayerDarkSelectedIndex.calledCount, 1)
        XCTAssertEqual(setPlayerDarkSelectedIndex.parameters, [GameData.Player.manual.rawValue])

        let setPlayerLightSelectedIndex = dependency.$setPlayerLightSelectedIndex
        XCTAssertEqual(setPlayerLightSelectedIndex.calledCount, 1)
        XCTAssertEqual(setPlayerLightSelectedIndex.parameters, [GameData.Player.manual.rawValue])

        let updateMessageViews = dependency.$updateMessageViews
        XCTAssertEqual(updateMessageViews.calledCount, 1)

        let updateCountLabels = dependency.$updateCountLabels
        XCTAssertEqual(updateCountLabels.calledCount, 1)

        let saveGame = dependency.$saveGame
        XCTAssertEqual(saveGame.parameters.isEmpty, false)
    }

    func test_loadGame() throws {
        let viewModel = dependency.testTarget

        let expectedCell = GameData.Board.Cell(x: 0, y: 0, disk: nil)
        let expectedPlayerDark = GameData.Player.computer
        let expectedPlayerLight = GameData.Player.computer

        dependency.gameData = GameData(
            status: .turn(.dark),
            playerDark: expectedPlayerDark,
            playerLight: expectedPlayerLight,
            board: GameData.Board(cells: [[expectedCell]])
        )

        try viewModel.loadGame()

        XCTAssertEqual(viewModel.turn, .dark)

        let setPlayerDarkSelectedIndex = dependency.$setPlayerDarkSelectedIndex
        XCTAssertEqual(setPlayerDarkSelectedIndex.calledCount, 1)
        XCTAssertEqual(setPlayerDarkSelectedIndex.parameters, [expectedPlayerDark.rawValue])

        let setPlayerLightSelectedIndex = dependency.$setPlayerLightSelectedIndex
        XCTAssertEqual(setPlayerLightSelectedIndex.calledCount, 1)
        XCTAssertEqual(setPlayerLightSelectedIndex.parameters, [expectedPlayerLight.rawValue])

        let setDisk = dependency.$setDisk
        XCTAssertEqual(setDisk.calledCount, 1)

        let parameter = try XCTUnwrap(setDisk.parameters.first)
        XCTAssertEqual(parameter.0, expectedCell.disk)
        XCTAssertEqual(parameter.1, expectedCell.x)
        XCTAssertEqual(parameter.2, expectedCell.y)
        XCTAssertEqual(parameter.3, false)

        let updateMessageViews = dependency.$updateMessageViews
        XCTAssertEqual(updateMessageViews.calledCount, 1)

        let updateCountLabels = dependency.$updateCountLabels
        XCTAssertEqual(updateCountLabels.calledCount, 1)
    }

    func test_saveGame() throws {
        let expectedCell = GameData.Board.Cell(
            x: 1,
            y: 2,
            disk: .dark
        )

        self.dependency = Dependency(board: .init(cells: [[expectedCell]]))
        let viewModel = dependency.testTarget

        let expectedPayerDark: GameData.Player = .manual
        dependency.getPlayerDarkSelectedIndex = expectedPayerDark.rawValue

        let expectedPlayerLight: GameData.Player = .computer
        dependency.getPlayerLightSelectedIndex = expectedPlayerLight.rawValue

        let expectedTurn: Disk = .light
        viewModel.turn = expectedTurn

        try viewModel.saveGame()

        let saveGame = dependency.$saveGame
        XCTAssertEqual(saveGame.calledCount, 1)

        let expectedGameData = GameData(
            status: .turn(expectedTurn),
            playerDark: expectedPayerDark,
            playerLight: expectedPlayerLight,
            board: GameData.Board(cells: [[expectedCell]])
        )
        XCTAssertEqual(saveGame.parameters, [expectedGameData])
    }

    func test_count() {
        let disk = Disk.dark
        let y = 2
        let x = 3
        let cells: [[GameData.Board.Cell]] = (0..<y).map { y in
            (0..<x).map { x in
                GameData.Board.Cell(x: x, y: y, disk: disk)
            }
        }

        self.dependency = Dependency(board: .init(cells: cells))
        let viewModel = dependency.testTarget

        let count = viewModel.count(of: .dark)
        XCTAssertEqual(count, x * y)
    }
}

extension ReversiViewModelTests {

    final class Dependency {

        @MockResponse<Void, Void>()
        var _playTurnOfComputer: Void

        @MockResponse<Int, Int>
        var _selectedSegmentIndexFor = 0

        @MockResponse<(Disk?, Int, Int, Bool), Void>()
        var setDisk: Void

        @MockResponse<Int, Void>()
        var setPlayerDarkSelectedIndex: Void

        @MockResponse<Void, Int>
        var getPlayerDarkSelectedIndex = 0

        @MockResponse<Int, Void>()
        var setPlayerLightSelectedIndex: Void

        @MockResponse<Void, Int>()
        var getPlayerLightSelectedIndex = 0

        @MockResponse<Void, Void>()
        var updateCountLabels: Void

        @MockResponse<Void, Void>()
        var updateMessageViews: Void

        @MockResponse<GameData, Void>()
        var saveGame: Void

        @MockResponse<Void, Void>()
        var reset: Void

        var gameData = Const.initialData

        private let board: GameData.Board

        private(set) lazy var testTarget = ReversiViewModel(
            playTurnOfComputer: { [weak self] in self?.playTurnOfComputer() },
            selectedSegmentIndexFor: { [weak self] in self?.selectedSegmentIndexFor($0) },
            setDisk: { [weak self] disk, x, y, animated, _ in self?._setDisk.respond((disk, x, y, animated)) },
            setPlayerDarkSelectedIndex: { [weak self] in self?._setPlayerDarkSelectedIndex.respond($0) },
            getPlayerDarkSelectedIndex: { [weak self] in self?._getPlayerDarkSelectedIndex.respond() },
            setPlayerLightSelectedIndex: { [weak self] in self?._setPlayerLightSelectedIndex.respond($0) },
            getPlayerLightSelectedIndex: { [weak self] in self?._getPlayerLightSelectedIndex.respond() },
            updateCountLabels: { [weak self] in self?._updateCountLabels.respond() },
            updateMessageViews: { [weak self] in self?._updateMessageViews.respond() },
            reset: { [weak self] in self?._reset.respond() },
            loadGame: { [weak self] _, completion in completion(self?.gameData ?? Const.initialData) },
            saveGame: { [weak self] data, _ in self?._saveGame.respond(data) },
            board: board
        )

        init(board: GameData.Board) {
            self.board = board
        }

        func playTurnOfComputer() {
            __playTurnOfComputer.respond()
        }

        func selectedSegmentIndexFor(_ index: Int) -> Int {
            return __selectedSegmentIndexFor.respond(index)
        }
    }
}

extension ReversiViewModelTests.Dependency {

    private enum Const {
        static let initialData = GameData(
            status: .turn(.dark),
            playerDark: .manual,
            playerLight: .manual,
            board: .initial()
        )
    }
}
