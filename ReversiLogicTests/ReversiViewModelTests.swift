import XCTest
@testable import ReversiLogic

final class ReversiViewModelTests: XCTestCase {

    private var dependency: Dependency!

    override func setUp() {
        self.dependency = Dependency(board: .initial(), messageDiskSize: 0)
    }

    func test_turn() {
        let viewModel = dependency.testTarget
        let cache = dependency.gameDataCache

        cache.status = .gameOver
        XCTAssertNil(viewModel.turn)

        cache.status = .turn(.light)
        XCTAssertEqual(viewModel.turn, .light)
    }

    func test_waitForPlayer_turnがdarkで_playerDarkがmanualの場合() {
        let viewModel = dependency.testTarget
        let cache = dependency.gameDataCache
        let turn = Disk.dark
        cache.status = .turn(turn)
        cache.playerDark = .manual

        viewModel.waitForPlayer()

        let playTurnOfComputer = dependency.$playTurnOfComputer
        XCTAssertEqual(playTurnOfComputer.calledCount, 0)
    }

    func test_waitForPlayer_turnがlightで_playerLightがcomputerの場合() {
        let viewModel = dependency.testTarget
        let cache = dependency.gameDataCache
        let turn = Disk.light
        cache.status = .turn(turn)
        cache.playerLight = .computer

        viewModel.waitForPlayer()

        let playTurnOfComputer = dependency.$playTurnOfComputer
        XCTAssertEqual(playTurnOfComputer.calledCount, 1)
    }

    func test_waitForPlayer_statusがgameOverの場合() {
        let viewModel = dependency.testTarget
        let cache = dependency.gameDataCache
        cache.status = .gameOver
        cache.playerDark = .computer
        cache.playerLight = .computer

        viewModel.waitForPlayer()

        let playTurnOfComputer = dependency.$playTurnOfComputer
        XCTAssertEqual(playTurnOfComputer.calledCount, 0)
    }

    func test_viewDidAppear_selectedSegmentIndexForが2回呼ばれることはない() {
        let viewModel = dependency.testTarget
        let cache = dependency.gameDataCache
        cache.playerDark = .computer
        let turn = Disk.dark

        cache.status = .turn(turn)
        viewModel.viewDidAppear()

        let playTurnOfComputer = dependency.$playTurnOfComputer
        XCTAssertEqual(playTurnOfComputer.calledCount, 1)

        viewModel.viewDidAppear()
        XCTAssertEqual(playTurnOfComputer.calledCount, 1)
    }

    func test_newGame() {
        let viewModel = dependency.testTarget
        let cache = dependency.gameDataCache

        viewModel.newGame()

        let reset = dependency.$reset
        XCTAssertEqual(reset.calledCount, 1)

        let cacheReset = cache.$_reset
        XCTAssertEqual(cacheReset.calledCount, 1)

        let setPlayerDarkSelectedIndex = dependency.$setPlayerDarkSelectedIndex
        XCTAssertEqual(setPlayerDarkSelectedIndex.calledCount, 1)
        XCTAssertEqual(setPlayerDarkSelectedIndex.parameters, [GameData.Player.manual.rawValue])

        let setPlayerLightSelectedIndex = dependency.$setPlayerLightSelectedIndex
        XCTAssertEqual(setPlayerLightSelectedIndex.calledCount, 1)
        XCTAssertEqual(setPlayerLightSelectedIndex.parameters, [GameData.Player.manual.rawValue])

        let save = cache.$_save
        XCTAssertEqual(save.parameters.isEmpty, false)
    }

    func test_loadGame() throws {
        let viewModel = dependency.testTarget
        let cache = dependency.gameDataCache

        let expectedCell = GameData.Board.Cell(x: 0, y: 0, disk: nil)
        let expectedPlayerDark = GameData.Player.computer
        let expectedPlayerLight = GameData.Player.computer

        cache.status = .turn(.dark)
        cache.playerDark = expectedPlayerDark
        cache.playerLight = expectedPlayerLight
        cache.cells = [[expectedCell]]

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
        self.dependency = Dependency(board: .initial(),
                                     messageDiskSize: 0)
        let viewModel = dependency.testTarget
        let cache = dependency.gameDataCache

        try viewModel.saveGame()

        let save = cache.$_save
        XCTAssertEqual(save.calledCount, 1)
    }

    func test_setSelectedIndex() {
        let viewModel = dependency.testTarget
        let cache = dependency.gameDataCache
        cache.playerDark = .manual
        cache.playerLight = .manual

        viewModel.setSelectedIndex(1, for: .dark)
        viewModel.setSelectedIndex(1, for: .light)

        XCTAssertEqual(cache.playerDark, .computer)
        XCTAssertEqual(cache.playerLight, .computer)
    }

    func test_updateMessage_trunがnilじゃない場合() {
        let expectedSize = CGFloat(arc4random() % 100)
        self.dependency = Dependency(board: .initial(), messageDiskSize: expectedSize)

        let expectedTurn = Disk.light
        let viewModel = dependency.testTarget
        let cache = dependency.gameDataCache
        cache.status = .turn(expectedTurn)

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
        let cache = dependency.gameDataCache
        cache.status = .gameOver

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
        let cache = dependency.gameDataCache
        cache.status = .gameOver

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
        let cache = dependency.gameDataCache
        cache.status = .turn(.light)

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
        let cache = dependency.gameDataCache
        cache.status = .turn(.light)

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
        let cache = dependency.gameDataCache
        cache.status = .turn(.light)

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

        @MockResponse<(Disk?, Int, Int, Bool), Void>()
        var setDisk: Void

        @MockResponse<Int, Void>()
        var setPlayerDarkSelectedIndex: Void

        @MockResponse<Int, Void>()
        var setPlayerLightSelectedIndex: Void

        @MockResponse<Void, Void>()
        var reset: Void

        let gameDataCache = MockGameDataCache()

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
            setDisk: { [weak self] disk, x, y, animated, _ in self?._setDisk.respond((disk, x, y, animated)) },
            setPlayerDarkSelectedIndex: { [weak self] in self?._setPlayerDarkSelectedIndex.respond($0) },
            setPlayerLightSelectedIndex: { [weak self] in self?._setPlayerLightSelectedIndex.respond($0) },
            reset: { [weak self] in self?._reset.respond() },
            cache: gameDataCache
        )

        init(board: GameData.Board, messageDiskSize: CGFloat) {
            self.gameDataCache.cells = board.cells
            self.messageDiskSize = messageDiskSize
        }
    }

    fileprivate final class MockGameDataCache: GameDataCacheProtocol {
        var status: GameData.Status = .turn(.dark)
        var playerDark: GameData.Player = .manual
        var playerLight: GameData.Player = .manual
        var cells: [[GameData.Board.Cell]] = []

        @MockResponse<Void, Void>()
        var _load: Void

        @MockResponse<Void, Void>()
        var _save: Void

        @MockResponse<Void, Void>()
        var _reset: Void

        @MockResponse<Coordinate, Disk?>
        var _getDisk = nil

        @MockResponse<(Coordinate, Disk?), Void>()
        var _setDisk: Void

        subscript(coordinate: Coordinate) -> Disk? {
            get { __getDisk.respond(coordinate) }
            set { __setDisk.respond((coordinate, newValue)) }
        }

        func load(completion: @escaping () -> Void) throws {
            __load.respond()
            completion()
        }

        func save() throws {
            __save.respond()
        }

        func reset() {
            __reset.respond()
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
