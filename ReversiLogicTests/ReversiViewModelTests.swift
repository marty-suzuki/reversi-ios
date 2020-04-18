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

    func test_playerOfCurrentTurn() {
        let viewModel = dependency.testTarget
        let cache = dependency.gameDataCache
        
        cache.status = .gameOver
        XCTAssertNil(viewModel.playerOfCurrentTurn)

        cache.status = .turn(.dark)
        cache._getPlayerDark = .computer
        XCTAssertEqual(viewModel.playerOfCurrentTurn, .computer)
        XCTAssertEqual(cache.$_getPlayerDark.parameters, [.dark])

        cache.status = .turn(.light)
        cache._getPlayerLight = .computer
        XCTAssertEqual(viewModel.playerOfCurrentTurn, .computer)
        XCTAssertEqual(cache.$_getPlayerLight.parameters, [.light])
    }

    func test_waitForPlayer_turnがdarkで_playerDarkがmanualの場合() {
        let viewModel = dependency.testTarget
        let cache = dependency.gameDataCache
        let turn = Disk.dark
        cache.status = .turn(turn)
        cache._getPlayerDark = .manual

        viewModel.waitForPlayer()

        let startPlayerDarkAnimation = dependency.$startPlayerDarkAnimation
        XCTAssertEqual(startPlayerDarkAnimation.calledCount, 0)

        let startPlayerLightAnimation = dependency.$startPlayerLightAnimation
         XCTAssertEqual(startPlayerLightAnimation.calledCount, 0)
    }

    func test_waitForPlayer_turnがlightで_playerLightがcomputerの場合() {
        let viewModel = dependency.testTarget
        let cache = dependency.gameDataCache
        let turn = Disk.light
        cache.status = .turn(turn)
        cache._getPlayerLight = .computer

        viewModel.waitForPlayer()

        let startPlayerDarkAnimation = dependency.$startPlayerDarkAnimation
        XCTAssertEqual(startPlayerDarkAnimation.calledCount, 0)

        let startPlayerLightAnimation = dependency.$startPlayerLightAnimation
         XCTAssertEqual(startPlayerLightAnimation.calledCount, 1)
    }

    func test_waitForPlayer_statusがgameOverの場合() {
        let viewModel = dependency.testTarget
        let cache = dependency.gameDataCache
        cache.status = .gameOver
        cache._getPlayerDark = .computer
        cache._getPlayerLight = .computer

        viewModel.waitForPlayer()

        let startPlayerDarkAnimation = dependency.$startPlayerDarkAnimation
        XCTAssertEqual(startPlayerDarkAnimation.calledCount, 0)

        let startPlayerLightAnimation = dependency.$startPlayerLightAnimation
         XCTAssertEqual(startPlayerLightAnimation.calledCount, 0)
    }

    func test_viewDidAppear_waitForPlayerが2回呼ばれることはない() {
        let viewModel = dependency.testTarget
        let cache = dependency.gameDataCache
        cache._getPlayerDark = .computer
        let turn = Disk.dark

        cache.status = .turn(turn)
        viewModel.viewDidAppear()

        let getPlayerDark = cache.$_getPlayerDark
        XCTAssertEqual(getPlayerDark.calledCount, 1)

        viewModel.viewDidAppear()
        XCTAssertEqual(getPlayerDark.calledCount, 1)
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
        cache._getPlayerDark = expectedPlayerDark
        cache._getPlayerLight = expectedPlayerLight
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

    func test_setPlayer_playerDarkに値が反映される() {
        let viewModel = dependency.testTarget
        let cache = dependency.gameDataCache
        let disk = Disk.dark
        cache._getPlayerDark = .manual

        viewModel.setPlayer(for: disk, with: 1)
        let first = MockGameDataCache.SetPlayer(disk: disk, player: .computer)
        XCTAssertEqual(cache.$_setPalyerDark.parameters, [first])

        viewModel.setPlayer(for: disk, with: 0)
        let second = MockGameDataCache.SetPlayer(disk: disk, player: .manual)
        XCTAssertEqual(cache.$_setPalyerDark.parameters, [first, second])
    }

    func test_setPlayer_playerLightに値が反映される() {
        let viewModel = dependency.testTarget
        let cache = dependency.gameDataCache
        let disk = Disk.light
        cache._getPlayerLight = .manual

        viewModel.setPlayer(for: disk, with: 1)
        let first = MockGameDataCache.SetPlayer(disk: disk, player: .computer)
        XCTAssertEqual(cache.$_setPalyerLight.parameters, [first])

        viewModel.setPlayer(for: disk, with: 0)
        let second = MockGameDataCache.SetPlayer(disk: disk, player: .manual)
        XCTAssertEqual(cache.$_setPalyerLight.parameters, [first, second])
    }

    func test_setPlayer_isAnimatingがfalseで_diskと現在のplayerが一致していて_playerがcomputerの場合() {
        let viewModel = dependency.testTarget
        let cache = dependency.gameDataCache
        let disk = Disk.light
        cache.status = .turn(disk)

        viewModel.animationCanceller = nil  // isAnimating = false
        cache._getPlayerLight = .computer

        viewModel.setPlayer(for: disk, with: 1)

        let startPlayerDarkAnimation = dependency.$startPlayerDarkAnimation
        XCTAssertEqual(startPlayerDarkAnimation.calledCount, 0)

        let startPlayerLightAnimation = dependency.$startPlayerLightAnimation
        XCTAssertEqual(startPlayerLightAnimation.calledCount, 1)
    }

    func test_setPlayer_isAnimatingがtrueで_diskと現在のplayerが一致していて_playerがcomputerの場合() {
        let viewModel = dependency.testTarget
        let cache = dependency.gameDataCache
        let disk = Disk.light
        cache.status = .turn(disk)

        viewModel.animationCanceller = Canceller({}) // isAnimating = true
        cache._getPlayerLight = .computer

        viewModel.setPlayer(for: disk, with: 1)

        let startPlayerLightAnimation = dependency.$startPlayerLightAnimation
        XCTAssertEqual(startPlayerLightAnimation.calledCount, 0)

        let startPlayerDarkAnimation = dependency.$startPlayerDarkAnimation
        XCTAssertEqual(startPlayerDarkAnimation.calledCount, 0)
    }

    func test_setPlayer_isAnimatingがfalseで_diskと現在のplayerが不一致で_playerがcomputerの場合() {
        let viewModel = dependency.testTarget
        let cache = dependency.gameDataCache
        cache.status = .turn(.light)

        viewModel.animationCanceller = nil // isAnimating = false
        cache._getPlayerLight = .computer

        viewModel.setPlayer(for: .dark, with: 1)

        let startPlayerLightAnimation = dependency.$startPlayerLightAnimation
        XCTAssertEqual(startPlayerLightAnimation.calledCount, 0)

        let startPlayerDarkAnimation = dependency.$startPlayerDarkAnimation
        XCTAssertEqual(startPlayerDarkAnimation.calledCount, 0)
    }

    func test_setPlayer_isAnimatingがfalseで_diskと現在のplayerが一致していて_playerがmanualの場合() {
        let viewModel = dependency.testTarget
        let cache = dependency.gameDataCache
        let disk = Disk.light
        cache.status = .turn(disk)

        viewModel.animationCanceller = nil // isAnimating = false
        cache._getPlayerLight = .manual

        viewModel.setPlayer(for: disk, with: 0)

        let startPlayerLightAnimation = dependency.$startPlayerLightAnimation
        XCTAssertEqual(startPlayerLightAnimation.calledCount, 0)

        let startPlayerDarkAnimation = dependency.$startPlayerDarkAnimation
        XCTAssertEqual(startPlayerDarkAnimation.calledCount, 0)
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

        let showAlert = dependency.$showAlert
        XCTAssertEqual(showAlert.calledCount, 1)
        XCTAssertEqual(showAlert.parameters, [.pass(dismissHandler: {})])
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

    func test_playTurnOfComputer() throws {
        let viewModel = dependency.testTarget
        let cache = dependency.gameDataCache
        let disk = Disk.light
        cache.status = .turn(disk)

        viewModel.playTurnOfComputer()

        let startPlayerDarkAnimation = dependency.$startPlayerDarkAnimation
        XCTAssertEqual(startPlayerDarkAnimation.calledCount, 0)

        let startPlayerLightAnimation = dependency.$startPlayerLightAnimation
        XCTAssertEqual(startPlayerLightAnimation.calledCount, 1)

        let asyncAfter = dependency.$asyncAfter
        XCTAssertEqual(asyncAfter.calledCount, 1)

        XCTAssertNotNil(viewModel.playerCancellers[disk])

        let completion = try XCTUnwrap(asyncAfter.parameters.first?.completion)
        completion()

        let stopPlayerDarkAnimation = dependency.$stopPlayerDarkAnimation
        XCTAssertEqual(stopPlayerDarkAnimation.calledCount, 0)

        let stopPlayerLightAnimation = dependency.$stopPlayerLightAnimation
        XCTAssertEqual(stopPlayerLightAnimation.calledCount, 1)

        XCTAssertNil(viewModel.playerCancellers[disk])
    }

    func test_handleReset() {
        let viewModel = dependency.testTarget

        viewModel.handleReset()

        let showAlert = dependency.$showAlert
        XCTAssertEqual(showAlert.calledCount, 1)
        XCTAssertEqual(showAlert.parameters, [.reset(okHandler: {})])
    }

    func test_handleSelectedCoordinate() {
        let viewModel = dependency.testTarget
        let cache = dependency.gameDataCache

        let disk = Disk.dark
        cache.status = .turn(disk)
        cache._getPlayerDark = .manual

        viewModel.animationCanceller = nil

        let coordinate = Coordinate(x: 0, y: 0)
        viewModel.handle(selectedCoordinate: coordinate)

        let placeDisk = dependency.$placeDisk
        XCTAssertEqual(placeDisk.calledCount, 1)
        let expected = Dependency.PlaceDisk(
            disk: disk,
            x: coordinate.x,
            y: coordinate.y,
            animated: true
        )
        XCTAssertEqual(placeDisk.parameters, [expected])
    }
}

extension ReversiViewModelTests {

    fileprivate final class Dependency {

        @MockResponse<PlaceDisk, Bool>
        var placeDisk = false

        @MockResponse<Alert, Void>()
        var showAlert: Void

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

        @MockResponse<(Disk?, Int, Int, Bool), Bool>()
        var setDisk = false

        @MockResponse<Int, Void>()
        var setPlayerDarkSelectedIndex: Void

        @MockResponse<Int, Void>()
        var setPlayerLightSelectedIndex: Void

        @MockResponse<Void, Void>()
        var startPlayerDarkAnimation: Void

        @MockResponse<Void, Void>()
        var stopPlayerDarkAnimation: Void

        @MockResponse<Void, Void>()
        var startPlayerLightAnimation: Void

        @MockResponse<Void, Void>()
        var stopPlayerLightAnimation: Void

        @MockResponse<Void, Void>()
        var reset: Void

        @MockResponse<AsyncAfter, Void>()
        var asyncAfter: Void

        let gameDataCache = MockGameDataCache()

        private let messageDiskSize: CGFloat

        private(set) lazy var testTarget = ReversiViewModel(
            messageDiskSize: messageDiskSize,
            placeDisk: { [weak self] disk, x, y, animated, completion in
                guard let me = self else {
                    return
                }
                let finished = me._placeDisk.respond(.init(disk: disk, x: x, y: y, animated: animated))
                completion(finished)
            },
            showAlert: { [weak self] in self?._showAlert.respond($0) },
            setPlayerDarkCount: { [weak self] in self?._setPlayerDarkCount.respond($0) },
            setPlayerLightCount: { [weak self] in self?._setPlayerLightCount.respond($0) },
            setMessageDiskSizeConstant: { [weak self] in self?._setMessageDiskSizeConstant.respond($0) },
            setMessageDisk: { [weak self] in self?._setMessageDisk.respond($0) },
            setMessageText: { [weak self] in self?._setMessageText.respond($0) },
            setDisk: { [weak self] disk, x, y, animated, completion in
                guard let me = self else {
                    return
                }
                let finished = me._setDisk.respond((disk, x, y, animated))
                completion?(finished)
            },
            setPlayerDarkSelectedIndex: { [weak self] in self?._setPlayerDarkSelectedIndex.respond($0) },
            setPlayerLightSelectedIndex: { [weak self] in self?._setPlayerLightSelectedIndex.respond($0) },
            startPlayerDarkAnimation: { [weak self] in self?._startPlayerDarkAnimation.respond() },
            stopPlayerDarkAnimation: { [weak self] in self?._stopPlayerDarkAnimation.respond() },
            startPlayerLightAnimation: { [weak self] in self?._startPlayerLightAnimation.respond() },
            stopPlayerLightAnimation: { [weak self] in self?._stopPlayerLightAnimation.respond() },
            reset: { [weak self] in self?._reset.respond() },
            asyncAfter: { [weak self] in self?._asyncAfter.respond(.init(time: $0, completion: $1)) },
            cache: gameDataCache
        )

        init(board: GameData.Board, messageDiskSize: CGFloat) {
            self.gameDataCache.cells = board.cells
            self.messageDiskSize = messageDiskSize
        }
    }
}

extension ReversiViewModelTests.Dependency {
    struct AsyncAfter {
        let time: DispatchTime
        let completion: () -> Void
    }

    struct PlaceDisk: Equatable {
        let disk: Disk?
        let x: Int
        let y: Int
        let animated: Bool
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
