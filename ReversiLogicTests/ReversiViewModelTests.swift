import XCTest
@testable import ReversiLogic

final class ReversiViewModelTests: XCTestCase {

    private var dependency: Dependency!

    override func setUp() {
        self.dependency = Dependency(board: .initial(), messageDiskSize: 0)
    }

    func test_waitForPlayer_turnがdarkで_selectedSegmentIndexが0の場合() {
        let viewModel = dependency.testTarget
        let turn = Disk.dark

        viewModel.turn = turn
        dependency.selectedSegmentIndexFor = 0

        viewModel.waitForPlayer()

        let selectedSegmentIndexFor = dependency.$selectedSegmentIndexFor
        let playTurnOfComputer = dependency.$playTurnOfComputer
        XCTAssertEqual(selectedSegmentIndexFor.calledCount, 1)
        XCTAssertEqual(selectedSegmentIndexFor.parameters, [turn.index])
        XCTAssertEqual(playTurnOfComputer.calledCount, 0)
    }

    func test_waitForPlayer_turnがlightで_selectedSegmentIndexが1の場合() {
        let viewModel = dependency.testTarget
        let turn = Disk.light

        viewModel.turn = turn
        dependency.selectedSegmentIndexFor = 1

        viewModel.waitForPlayer()

        let selectedSegmentIndexFor = dependency.$selectedSegmentIndexFor
        let playTurnOfComputer = dependency.$playTurnOfComputer
        XCTAssertEqual(selectedSegmentIndexFor.calledCount, 1)
        XCTAssertEqual(selectedSegmentIndexFor.parameters, [turn.index])
        XCTAssertEqual(playTurnOfComputer.calledCount, 1)
    }

    func test_waitForPlayer_turnがnilの場合() {
        let viewModel = dependency.testTarget

        viewModel.turn = nil
        viewModel.waitForPlayer()

        let selectedSegmentIndexFor = dependency.$selectedSegmentIndexFor
        let playTurnOfComputer = dependency.$playTurnOfComputer
        XCTAssertEqual(selectedSegmentIndexFor.calledCount, 0)
        XCTAssertEqual(selectedSegmentIndexFor.parameters, [])
        XCTAssertEqual(playTurnOfComputer.calledCount, 0)
    }

    func test_viewDidAppear_selectedSegmentIndexForが2回呼ばれることはない() {
        let viewModel = dependency.testTarget
        let turn = Disk.dark

        viewModel.turn = turn
        viewModel.viewDidAppear()

        let selectedSegmentIndexFor = dependency.$selectedSegmentIndexFor
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

        let saveGame = dependency.gameDataCache.$saveGame
        XCTAssertEqual(saveGame.parameters.isEmpty, false)
    }

    func test_loadGame() throws {
        let viewModel = dependency.testTarget

        let expectedCell = GameData.Board.Cell(x: 0, y: 0, disk: nil)
        let expectedPlayerDark = GameData.Player.computer
        let expectedPlayerLight = GameData.Player.computer

        dependency.gameDataCache.gameData = GameData(
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
    }

    func test_saveGame() throws {
        let expectedCell = GameData.Board.Cell(
            x: 1,
            y: 2,
            disk: .dark
        )

        self.dependency = Dependency(board: .init(cells: [[expectedCell]]),
                                     messageDiskSize: 0)
        let viewModel = dependency.testTarget

        let expectedPayerDark: GameData.Player = .manual
        dependency.getPlayerDarkSelectedIndex = expectedPayerDark.rawValue

        let expectedPlayerLight: GameData.Player = .computer
        dependency.getPlayerLightSelectedIndex = expectedPlayerLight.rawValue

        let expectedTurn: Disk = .light
        viewModel.turn = expectedTurn

        try viewModel.saveGame()

        let saveGame = dependency.gameDataCache.$saveGame
        XCTAssertEqual(saveGame.calledCount, 1)

        let expectedGameData = GameData(
            status: .turn(expectedTurn),
            playerDark: expectedPayerDark,
            playerLight: expectedPlayerLight,
            board: GameData.Board(cells: [[expectedCell]])
        )
        XCTAssertEqual(saveGame.parameters, [expectedGameData])
    }

    func test_updateMessage_trunがnilじゃない場合() {
        let expectedSize = CGFloat(arc4random() % 100)
        self.dependency = Dependency(board: .initial(), messageDiskSize: expectedSize)

        let expectedTurn = Disk.light
        let viewModel = dependency.testTarget
        viewModel.turn = expectedTurn

        viewModel.updateMessage()

        let setMessageDiskSizeConstant = dependency.$setMessageDiskSizeConstant
        XCTAssertEqual(setMessageDiskSizeConstant.calledCount, 1)
        XCTAssertEqual(setMessageDiskSizeConstant.parameters, [expectedSize])

        let setMessageDisk = dependency.$setMessageDisk
        XCTAssertEqual(setMessageDisk.calledCount, 1)
        XCTAssertEqual(setMessageDisk.parameters, [expectedTurn])

        let setMessageText = dependency.$setMessageText
        XCTAssertEqual(setMessageText.calledCount, 1)
        XCTAssertEqual(setMessageText.parameters, ["'s turn"])
    }

    func test_updateMessage_trunがnilで勝者がいる場合() {
        let expectedDisk = Disk.dark
        let expectedSize = CGFloat(arc4random() % 100)
        let cell = GameData.Board.Cell(
            x: 1,
            y: 2,
            disk: expectedDisk
        )
        self.dependency = Dependency(board: .init(cells: [[cell]]),
                                     messageDiskSize: expectedSize)

        let viewModel = dependency.testTarget
        viewModel.turn = nil

        viewModel.updateMessage()

        let setMessageDiskSizeConstant = dependency.$setMessageDiskSizeConstant
        XCTAssertEqual(setMessageDiskSizeConstant.calledCount, 1)
        XCTAssertEqual(setMessageDiskSizeConstant.parameters, [expectedSize])

        let setMessageDisk = dependency.$setMessageDisk
        XCTAssertEqual(setMessageDisk.calledCount, 1)
        XCTAssertEqual(setMessageDisk.parameters, [expectedDisk])

        let setMessageText = dependency.$setMessageText
        XCTAssertEqual(setMessageText.calledCount, 1)
        XCTAssertEqual(setMessageText.parameters, [" won"])
    }

    func test_updateMessage_trunがnilで勝者がいない場合() {
        let cell1 = GameData.Board.Cell(
            x: 1,
            y: 2,
            disk: .dark
        )
        let cell2 = GameData.Board.Cell(
            x: 1,
            y: 2,
            disk: .light
        )
        self.dependency = Dependency(board: .init(cells: [[cell1, cell2]]),
                                     messageDiskSize: 0)

        let viewModel = dependency.testTarget
        viewModel.turn = nil

        viewModel.updateMessage()

        let setMessageDiskSizeConstant = dependency.$setMessageDiskSizeConstant
        XCTAssertEqual(setMessageDiskSizeConstant.calledCount, 1)
        XCTAssertEqual(setMessageDiskSizeConstant.parameters, [0])

        let setMessageDisk = dependency.$setMessageDisk
        XCTAssertEqual(setMessageDisk.calledCount, 0)

        let setMessageText = dependency.$setMessageText
        XCTAssertEqual(setMessageText.calledCount, 1)
        XCTAssertEqual(setMessageText.parameters, ["Tied"])
    }

    func test_updateCount() {
        let darkCount = Int(arc4random() % 100)
        let cells1 = (0..<darkCount)
            .map { _ in GameData.Board.Cell(x: 0, y: 0, disk: .dark) }

        let lightCount = Int(arc4random() % 100)
        let cells2 = (0..<lightCount)
            .map { _ in GameData.Board.Cell(x: 0, y: 0, disk: .light) }

        self.dependency = Dependency(board: .init(cells: [cells1, cells2]),
                                     messageDiskSize: 0)
        let viewModel = dependency.testTarget

        viewModel.updateCount()

        let setPlayerDarkCount = dependency.$setPlayerDarkCount
        XCTAssertEqual(setPlayerDarkCount.calledCount, 1)
        XCTAssertEqual(setPlayerDarkCount.parameters, ["\(darkCount)"])

        let setPlayerLightCount = dependency.$setPlayerLightCount
        XCTAssertEqual(setPlayerLightCount.calledCount, 1)
        XCTAssertEqual(setPlayerLightCount.parameters, ["\(lightCount)"])
    }
    func test_nextTurn_turnがlightのときに_darkの有効な配置がある場合() {
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
        self.dependency = Dependency(board: .init(cells: cells),
                                     messageDiskSize: 0)

        let viewModel = dependency.testTarget
        viewModel.turn = .light

        viewModel.nextTurn()

        XCTAssertEqual(viewModel.turn, .dark)
    }

    func test_nextTurn_turnがlightのときに_darkの有効な配置はないが_lightの有効な配置がある場合() {
        let board: [[Disk?]] = [
            [nil, nil,   nil],
            [nil, .dark, .dark],
            [nil, .light, nil]
        ]
        let cells = board.enumerated().map { y, rows in
            rows.enumerated().map { x, disk in
                GameData.Board.Cell(x: x, y: y, disk: disk)
            }
        }
        self.dependency = Dependency(board: .init(cells: cells),
                                     messageDiskSize: 0)

        let viewModel = dependency.testTarget
        viewModel.turn = .light

        viewModel.nextTurn()

        XCTAssertEqual(viewModel.turn, .dark)

        let showCanNotPlaceAlert = dependency.$showCanNotPlaceAlert
        XCTAssertEqual(showCanNotPlaceAlert.calledCount, 1)
    }

    func test_nextTurn_turnがlightのときに_darkもlightの有効な配置はない場合() {
        let board: [[Disk?]] = [
            [.light, .dark],
            [.dark, .light]
        ]
        let cells = board.enumerated().map { y, rows in
            rows.enumerated().map { x, disk in
                GameData.Board.Cell(x: x, y: y, disk: disk)
            }
        }
        self.dependency = Dependency(board: .init(cells: cells),
                                     messageDiskSize: 0)

        let viewModel = dependency.testTarget
        viewModel.turn = .light

        viewModel.nextTurn()

        XCTAssertNil(viewModel.turn)
    }
}

extension ReversiViewModelTests {

    fileprivate final class Dependency {

        @MockResponse<Void, Void>()
        var showCanNotPlaceAlert: Void

        @MockResponse<String, Void>()
        var setPlayerDarkCount: Void

        @MockResponse<String, Void>()
        var setPlayerLightCount: Void

        @MockResponse<CGFloat, Void>()
        var setMessageDiskSizeConstant: Void

        @MockResponse<Disk, Void>()
        var setMessageDisk: Void

        @MockResponse<String, Void>()
        var setMessageText: Void

        @MockResponse<Void, Void>()
        var playTurnOfComputer: Void

        @MockResponse<Int, Int>
        var selectedSegmentIndexFor = 0

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
        var reset: Void

        let gameDataCache = MockGameDataCache(gameData: Const.initialData)

        private let board: GameData.Board
        private let messageDiskSize: CGFloat

        private(set) lazy var testTarget = ReversiViewModel(
            messageDiskSize: messageDiskSize,
            showCanNotPlaceAlert: { [weak self] in self?._showCanNotPlaceAlert.respond() },
            setPlayerDarkCount: { [weak self] in self?._setPlayerDarkCount.respond($0) },
            setPlayerLightCount: { [weak self] in self?._setPlayerLightCount.respond($0) },
            setMessageDiskSizeConstant: { [weak self] in self?._setMessageDiskSizeConstant.respond($0) },
            setMessageDisk: { [weak self] in self?._setMessageDisk.respond($0) },
            setMessageText: { [weak self] in self?._setMessageText.respond($0) },
            playTurnOfComputer: { [weak self] in self?._playTurnOfComputer.respond() },
            selectedSegmentIndexFor: { [weak self] in self?._selectedSegmentIndexFor.respond($0) },
            setDisk: { [weak self] disk, x, y, animated, _ in self?._setDisk.respond((disk, x, y, animated)) },
            setPlayerDarkSelectedIndex: { [weak self] in self?._setPlayerDarkSelectedIndex.respond($0) },
            getPlayerDarkSelectedIndex: { [weak self] in self?._getPlayerDarkSelectedIndex.respond() },
            setPlayerLightSelectedIndex: { [weak self] in self?._setPlayerLightSelectedIndex.respond($0) },
            getPlayerLightSelectedIndex: { [weak self] in self?._getPlayerLightSelectedIndex.respond() },
            reset: { [weak self] in self?._reset.respond() },
            cache: gameDataCache,
            board: board
        )

        init(board: GameData.Board, messageDiskSize: CGFloat) {
            self.board = board
            self.messageDiskSize = messageDiskSize
        }
    }

    fileprivate final class MockGameDataCache: GameDataCacheProtocol {

        @MockResponse<GameData, Void>()
        var saveGame: Void

        var gameData: GameData

        init(gameData: GameData) {
            self.gameData = gameData
        }

        func load(completion: @escaping (GameData) -> Void) throws {
            completion(gameData)
        }

        func save(data: GameData) throws {
            _saveGame.respond(data)
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
