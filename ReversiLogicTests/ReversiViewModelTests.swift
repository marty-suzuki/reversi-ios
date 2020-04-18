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
        XCTAssertEqual(parameter.disk, expectedCell.disk)
        XCTAssertEqual(parameter.x, expectedCell.x)
        XCTAssertEqual(parameter.y, expectedCell.y)
        XCTAssertEqual(parameter.animated, false)
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
        cache.playerOfCurrentTurn = .manual
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

// - MARK: animateSettingDisks

extension ReversiViewModelTests {

    func test_animateSettingDisks_coordinatesが0件の場合() {
        let viewModel = dependency.testTarget

        var isFinished: Bool?
        viewModel.animateSettingDisks(at: [], to: .dark) {
            isFinished = $0
        }

        XCTAssertEqual(isFinished, true)
    }

    func test_animateSettingDisks_animationCancellerがnilの場合() {
        let viewModel = dependency.testTarget

        let coordinates = [(0, 0), (1, 1)]
        let disk = Disk.dark
        viewModel.animationCanceller = nil

        var isFinished: Bool?
        viewModel.animateSettingDisks(at: coordinates, to: disk) {
            isFinished = $0
        }

        XCTAssertNil(isFinished)
    }

    func test_animateSettingDisks_animationCancellerを途中でキャンセルした場合() throws {
        let viewModel = dependency.testTarget

        let coordinates = [(0, 0), (1, 1)]
        let disk = Disk.dark
        viewModel.animationCanceller = Canceller({})

        var isFinished: Bool?
        viewModel.animateSettingDisks(at: coordinates, to: disk) {
            isFinished = $0
        }

        let expected = Dependency.SetDisk(disk: disk,
                                          x: 0,
                                          y: 0,
                                          animated: true,
                                          completion: nil)

        let paramater = try XCTUnwrap(dependency.$setDisk.parameters.first)

        XCTAssertEqual(paramater, expected)
        XCTAssertEqual(dependency.$setDisk.calledCount, 1)

        viewModel.animationCanceller?.cancel()
        paramater.completion?(false)

        XCTAssertNil(isFinished)
    }

    func test_animateSettingDisks_setDiskのfinishedがfalseの場合() throws {
        let viewModel = dependency.testTarget

        let coordinates = [(0, 0), (1, 1)]
        let disk = Disk.dark
        viewModel.animationCanceller = Canceller({})

        var isFinished: Bool?
        viewModel.animateSettingDisks(at: coordinates, to: disk) {
            isFinished = $0
        }

        let expected = Dependency.SetDisk(disk: disk,
                                          x: 0,
                                          y: 0,
                                          animated: true,
                                          completion: nil)

        do {
            let paramater = try XCTUnwrap(dependency.$setDisk.parameters.first)

            XCTAssertEqual(paramater, expected)
            XCTAssertEqual(dependency.$setDisk.calledCount, 1)

            paramater.completion?(false)
        }

        do {
            let expected1 = Dependency.SetDisk(disk: disk,
                                               x: 0,
                                               y: 0,
                                               animated: false,
                                               completion: nil)

            let expected2 = Dependency.SetDisk(disk: disk,
                                               x: 1,
                                               y: 1,
                                               animated: false,
                                               completion: nil)

            XCTAssertEqual(dependency.$setDisk.parameters, [expected, expected1, expected2])
            XCTAssertEqual(dependency.$setDisk.calledCount, 3)
        }

        XCTAssertEqual(isFinished, false)
    }

    func test_animateSettingDisks_setDiskのfinishedがtrueの場合() throws {
        let viewModel = dependency.testTarget

        let coordinates = [(0, 0), (1, 1)]
        let disk = Disk.dark
        viewModel.animationCanceller = Canceller({})

        var isFinished: Bool?
        viewModel.animateSettingDisks(at: coordinates, to: disk) {
            isFinished = $0
        }

        do {
            let paramater = try XCTUnwrap(dependency.$setDisk.parameters.last)

            let expected = Dependency.SetDisk(disk: disk,
                                              x: 0,
                                              y: 0,
                                              animated: true,
                                              completion: nil)

            XCTAssertEqual(paramater, expected)
            XCTAssertEqual(dependency.$setDisk.calledCount, 1)

            paramater.completion?(true)
        }

        do {
            let paramater = try XCTUnwrap(dependency.$setDisk.parameters.last)

            let expected = Dependency.SetDisk(disk: disk,
                                              x: 1,
                                              y: 1,
                                              animated: true,
                                              completion: nil)

            XCTAssertEqual(paramater, expected)
            XCTAssertEqual(dependency.$setDisk.calledCount, 2)

            paramater.completion?(true)
        }

        XCTAssertEqual(isFinished, true)
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

        @MockResponse<SetDisk, Void>()
        var setDisk: Void

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
                me._setDisk.respond(.init(disk: disk, x: x, y: y, animated: animated, completion: completion))
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

    struct SetDisk: Equatable {
        let disk: Disk?
        let x: Int
        let y: Int
        let animated: Bool
        let completion: ((Bool) -> Void)?
    }
}

extension ReversiViewModelTests.Dependency.SetDisk {
    fileprivate static func == (
        lhs: ReversiViewModelTests.Dependency.SetDisk,
        rhs: ReversiViewModelTests.Dependency.SetDisk
    ) -> Bool {
        return lhs.disk == rhs.disk &&
            lhs.x == rhs.x &&
            lhs.y == rhs.y &&
            lhs.animated == rhs.animated
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
