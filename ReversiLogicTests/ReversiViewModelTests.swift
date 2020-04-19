import RxSwift
import XCTest
@testable import ReversiLogic

final class ReversiViewModelTests: XCTestCase {

    private var dependency: Dependency!

    override func setUp() {
        self.dependency = Dependency(cells: GameData.initial.cells,
                                     messageDiskSize: 0)
    }

    func test_viewDidAppear_waitForPlayerが2回呼ばれることはない() {
        let viewModel = dependency.testTarget
        let cache = dependency.gameDataCache
        cache.$playerDark.accept(.manual)
        let turn = Disk.dark
        cache.$status.accept(.turn(turn))
        let logic = dependency.gameLogic
        logic._validMovekForDark = [Coordinate(x: 0, y: 0)]
        let waitForPlayer = logic.$_waitForPlayer

        viewModel.viewDidAppear()
        XCTAssertEqual(waitForPlayer.calledCount, 1)

        viewModel.viewDidAppear()
        XCTAssertEqual(waitForPlayer.calledCount, 1)
    }

    func test_newGame() {
        let viewModel = dependency.testTarget
        let cache = dependency.gameDataCache

        viewModel.newGame()

        let reset = dependency.$reset
        XCTAssertEqual(reset.calledCount, 1)

        let cacheReset = cache.$_reset
        XCTAssertEqual(cacheReset.calledCount, 1)

        let save = cache.$_save
        XCTAssertEqual(save.parameters.isEmpty, false)
    }

    func test_loadGame() throws {
        let viewModel = dependency.testTarget
        let cache = dependency.gameDataCache

        let expectedCell = GameData.Cell(coordinate: .init(x: 0, y: 0), disk: nil)
        let expectedPlayerDark = GameData.Player.computer
        let expectedPlayerLight = GameData.Player.computer

        cache.$status.accept(.turn(.dark))
        cache.$playerDark.accept(expectedPlayerDark)
        cache.$playerLight.accept(expectedPlayerLight)
        cache.$cells.accept([[expectedCell]])

        try viewModel.loadGame()

        XCTAssertEqual(cache.status.value, .turn(.dark))

        let setPlayerDarkSelectedIndex = dependency.$setPlayerDarkSelectedIndex
        XCTAssertEqual(setPlayerDarkSelectedIndex.calledCount, 1)
        XCTAssertEqual(setPlayerDarkSelectedIndex.parameters, [expectedPlayerDark.rawValue])

        let setPlayerLightSelectedIndex = dependency.$setPlayerLightSelectedIndex
        XCTAssertEqual(setPlayerLightSelectedIndex.calledCount, 1)
        XCTAssertEqual(setPlayerLightSelectedIndex.parameters, [expectedPlayerLight.rawValue])

        let updateBoard = dependency.$updateBoard
        XCTAssertEqual(updateBoard.calledCount, 1)

        let parameter = try XCTUnwrap(updateBoard.parameters.first)
        XCTAssertEqual(parameter.disk, expectedCell.disk)
        XCTAssertEqual(parameter.coordinate, expectedCell.coordinate)
        XCTAssertEqual(parameter.animated, false)
    }

    func test_setPlayer_playerDarkに値が反映される() {
        let viewModel = dependency.testTarget
        let cache = dependency.gameDataCache
        let disk = Disk.dark
        cache.$playerDark.accept(.manual)

        viewModel.setPlayer(for: disk, with: 1)
        XCTAssertEqual(cache.$_setPalyerDark.parameters, [.computer])

        viewModel.setPlayer(for: disk, with: 0)
        XCTAssertEqual(cache.$_setPalyerDark.parameters, [.computer, .manual])
    }

    func test_setPlayer_playerLightに値が反映される() {
        let viewModel = dependency.testTarget
        let cache = dependency.gameDataCache
        let disk = Disk.light
        cache.$playerLight.accept(.manual)

        viewModel.setPlayer(for: disk, with: 1)
        XCTAssertEqual(cache.$_setPalyerLight.parameters, [.computer])

        viewModel.setPlayer(for: disk, with: 0)
        XCTAssertEqual(cache.$_setPalyerLight.parameters, [.computer, .manual])
    }

    func test_setPlayer_isAnimatingがfalseで_diskと現在のplayerが一致していて_playerがcomputerの場合() {
        let viewModel = dependency.testTarget
        let cache = dependency.gameDataCache
        let disk = Disk.light
        cache.$status.accept(.turn(disk))
        let logic = dependency.gameLogic
        logic._validMovekForLight = [Coordinate(x: 0, y: 0)]

        viewModel.animationCanceller = nil  // isAnimating = false
        cache.$playerLight.accept(.computer)

        viewModel.setPlayer(for: disk, with: 1)

        let isPlayerDarkAnimating = dependency.$isPlayerDarkAnimating
        XCTAssertEqual(isPlayerDarkAnimating.calledCount, 0)

        let isPlayerLightAnimating = dependency.$isPlayerLightAnimating
        XCTAssertEqual(isPlayerLightAnimating.calledCount, 1)
    }

    func test_setPlayer_isAnimatingがtrueで_diskと現在のplayerが一致していて_playerがcomputerの場合() {
        let viewModel = dependency.testTarget
        let cache = dependency.gameDataCache
        let disk = Disk.light
        cache.$status.accept(.turn(disk))
        let logic = dependency.gameLogic
        logic._validMovekForLight = [Coordinate(x: 0, y: 0)]

        viewModel.animationCanceller = Canceller({}) // isAnimating = true
        cache.$playerLight.accept(.computer)

        viewModel.setPlayer(for: disk, with: 1)

        let isPlayerDarkAnimating = dependency.$isPlayerDarkAnimating
        XCTAssertEqual(isPlayerDarkAnimating.calledCount, 0)

        let isPlayerLightAnimating = dependency.$isPlayerLightAnimating
        XCTAssertEqual(isPlayerLightAnimating.calledCount, 0)
    }

    func test_setPlayer_isAnimatingがfalseで_diskと現在のplayerが不一致で_playerがcomputerの場合() {
        let viewModel = dependency.testTarget
        let cache = dependency.gameDataCache
        cache.$status.accept(.turn(.light))

        viewModel.animationCanceller = nil // isAnimating = false
        cache.$playerLight.accept(.computer)

        viewModel.setPlayer(for: .dark, with: 1)

        let isPlayerDarkAnimating = dependency.$isPlayerDarkAnimating
        XCTAssertEqual(isPlayerDarkAnimating.calledCount, 0)

        let isPlayerLightAnimating = dependency.$isPlayerLightAnimating
        XCTAssertEqual(isPlayerLightAnimating.calledCount, 0)
    }

    func test_setPlayer_isAnimatingがfalseで_diskと現在のplayerが一致していて_playerがmanualの場合() {
        let viewModel = dependency.testTarget
        let cache = dependency.gameDataCache
        let disk = Disk.light
        cache.$status.accept(.turn(disk))

        viewModel.animationCanceller = nil // isAnimating = false
        cache.$playerLight.accept(.manual)

        viewModel.setPlayer(for: disk, with: 0)

        let isPlayerDarkAnimating = dependency.$isPlayerDarkAnimating
        XCTAssertEqual(isPlayerDarkAnimating.calledCount, 0)

        let isPlayerLightAnimating = dependency.$isPlayerLightAnimating
        XCTAssertEqual(isPlayerLightAnimating.calledCount, 0)
    }

    func test_status_gameOverじゃない場合() {
        let expectedSize = CGFloat(arc4random() % 100)
        self.dependency = Dependency(cells: GameData.initial.cells, messageDiskSize: expectedSize)

        let expectedTurn = Disk.light
        let cache = dependency.gameDataCache
        cache.$status.accept(.turn(expectedTurn))

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

    func test_status_gameOverで勝者がいる場合() {
        let expectedDisk = Disk.dark
        let expectedSize = CGFloat(arc4random() % 100)
        self.dependency = Dependency(cells: [],
                                     messageDiskSize: expectedSize)

        let logic = dependency.gameLogic
        logic.$sideWithMoreDisks.accept(expectedDisk)
        let cache = dependency.gameDataCache
        cache.$status.accept(.gameOver)

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

    func test_status_gameOverで勝者がいない場合() {
        let cell1 = GameData.Cell(
            coordinate: .init(x: 1, y: 2),
            disk: .dark
        )
        let cell2 = GameData.Cell(
            coordinate: .init(x: 2, y: 2),
            disk: .light
        )
        self.dependency = Dependency(cells: [[cell1, cell2]],
                                     messageDiskSize: 0)

        let logic = dependency.gameLogic
        logic.$sideWithMoreDisks.accept(nil)
        let cache = dependency.gameDataCache
        cache.$status.accept(.gameOver)

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
        let lightCount = Int(arc4random() % 100)
        let viewModel = dependency.testTarget
        let logic = dependency.gameLogic
        logic.$countOfDark.accept(darkCount)
        logic.$countOfLight.accept(lightCount)

        viewModel.updateCount()

        let setPlayerDarkCount = dependency.$setPlayerDarkCount
        XCTAssertEqual(setPlayerDarkCount.calledCount, 1)
        XCTAssertEqual(setPlayerDarkCount.parameters, ["\(darkCount)"])

        let setPlayerLightCount = dependency.$setPlayerLightCount
        XCTAssertEqual(setPlayerLightCount.calledCount, 1)
        XCTAssertEqual(setPlayerLightCount.parameters, ["\(lightCount)"])
    }
    func test_nextTurn_statusがlightのときに_darkの有効な配置がある場合() {
        let viewModel = dependency.testTarget
        let cache = dependency.gameDataCache
        cache.$status.accept(.turn(.light))

        let logic = dependency.gameLogic
        logic._validMovekForDark = [Coordinate(x: 0, y: 0)]

        viewModel.nextTurn()

        XCTAssertEqual(cache.$_setStatus.parameters, [.turn(.dark)])
    }

    func test_nextTurn_statusがlightのときに_darkの有効な配置はないが_lightの有効な配置がある場合() {
        let viewModel = dependency.testTarget
        let cache = dependency.gameDataCache
        cache.$status.accept(.turn(.light))

        let logic = dependency.gameLogic
        logic._validMovekForDark = []
        logic._validMovekForLight = [Coordinate(x: 0, y: 0)]

        viewModel.nextTurn()

        XCTAssertEqual(cache.$_setStatus.parameters, [.turn(.dark)])

        let showAlert = dependency.$showAlert
        XCTAssertEqual(showAlert.calledCount, 1)
        XCTAssertEqual(showAlert.parameters, [.pass(dismissHandler: {})])
    }

    func test_nextTurn_statuがlightのときに_darkもlightの有効な配置はない場合() {
        let viewModel = dependency.testTarget
        let cache = dependency.gameDataCache
        cache.$status.accept(.turn(.light))

        let logic = dependency.gameLogic
        logic._validMovekForDark = []
        logic._validMovekForLight = []

        viewModel.nextTurn()

        XCTAssertEqual(cache.$_setStatus.parameters, [.gameOver])
    }

    func test_playTurnOfComputer() throws {
        let viewModel = dependency.testTarget
        let cache = dependency.gameDataCache
        let disk = Disk.light
        cache.$status.accept(.turn(disk))

        let coordinate = Coordinate(x: 0, y: 0)
        let logic = dependency.gameLogic
        logic._validMovekForLight = [coordinate]
        logic._flippedDiskCoordinates = [coordinate]

        viewModel.playTurnOfComputer()

        let isPlayerDarkAnimating = dependency.$isPlayerDarkAnimating
        XCTAssertEqual(isPlayerDarkAnimating.calledCount, 0)

        let isPlayerLightAnimating = dependency.$isPlayerLightAnimating
        XCTAssertEqual(isPlayerLightAnimating.calledCount, 1)

        let asyncAfter = dependency.$asyncAfter
        XCTAssertEqual(asyncAfter.calledCount, 1)

        XCTAssertNotNil(viewModel.playerCancellers[disk])

        let completion = try XCTUnwrap(asyncAfter.parameters.first?.completion)
        completion()

        XCTAssertEqual(isPlayerDarkAnimating.calledCount, 0)
        XCTAssertEqual(isPlayerLightAnimating.calledCount, 2)

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
        let logic = dependency.gameLogic

        let disk = Disk.dark
        cache.$status.accept(.turn(disk))
        logic.$playerOfCurrentTurn.accept(.manual)
        cache.$playerDark.accept(.manual)

        viewModel.animationCanceller = nil

        let coordinate = Coordinate(x: 0, y: 0)
        viewModel.handle(selectedCoordinate: coordinate)

        let flippedDiskCoordinates = logic.$_flippedDiskCoordinates
        let expected = MockGameLogic.FlippedDiskCoordinates(
            disk: disk,
            coordinate: coordinate
        )
        XCTAssertEqual(flippedDiskCoordinates.calledCount, 1)
        XCTAssertEqual(flippedDiskCoordinates.parameters, [expected])
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

        let coordinates = [Coordinate(x: 0, y: 0), Coordinate(x: 1, y: 1)]
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

        let coordinates = [Coordinate(x: 0, y: 0), Coordinate(x: 1, y: 1)]
        let disk = Disk.dark
        viewModel.animationCanceller = Canceller({})

        var isFinished: Bool?
        viewModel.animateSettingDisks(at: coordinates, to: disk) {
            isFinished = $0
        }

        let expected = Dependency.SetDisk(disk: disk,
                                          coordinate: .init(x: 0, y: 0),
                                          animated: true,
                                          completion: nil)

        let paramater = try XCTUnwrap(dependency.$updateBoard.parameters.first)

        XCTAssertEqual(paramater, expected)
        XCTAssertEqual(dependency.$updateBoard.calledCount, 1)

        viewModel.animationCanceller?.cancel()
        paramater.completion?(false)

        XCTAssertNil(isFinished)
    }

    func test_animateSettingDisks_setDiskのfinishedがfalseの場合() throws {
        let viewModel = dependency.testTarget

        let coordinates = [Coordinate(x: 0, y: 0), Coordinate(x: 1, y: 1)]
        let disk = Disk.dark
        viewModel.animationCanceller = Canceller({})

        var isFinished: Bool?
        viewModel.animateSettingDisks(at: coordinates, to: disk) {
            isFinished = $0
        }

        let expected = Dependency.SetDisk(disk: disk,
                                          coordinate: .init(x: 0, y: 0),
                                          animated: true,
                                          completion: nil)

        do {
            let paramater = try XCTUnwrap(dependency.$updateBoard.parameters.first)

            XCTAssertEqual(paramater, expected)
            XCTAssertEqual(dependency.$updateBoard.calledCount, 1)

            paramater.completion?(false)
        }

        do {
            let expected1 = Dependency.SetDisk(disk: disk,
                                               coordinate: .init(x: 0, y: 0),
                                               animated: false,
                                               completion: nil)

            let expected2 = Dependency.SetDisk(disk: disk,
                                               coordinate: .init(x: 1, y: 1),
                                               animated: false,
                                               completion: nil)

            XCTAssertEqual(dependency.$updateBoard.parameters, [expected, expected1, expected2])
            XCTAssertEqual(dependency.$updateBoard.calledCount, 3)
        }

        XCTAssertEqual(isFinished, false)
    }

    func test_animateSettingDisks_setDiskのfinishedがtrueの場合() throws {
        let viewModel = dependency.testTarget

        let coordinates = [Coordinate(x: 0, y: 0), Coordinate(x: 1, y: 1)]
        let disk = Disk.dark
        viewModel.animationCanceller = Canceller({})

        var isFinished: Bool?
        viewModel.animateSettingDisks(at: coordinates, to: disk) {
            isFinished = $0
        }

        do {
            let paramater = try XCTUnwrap(dependency.$updateBoard.parameters.last)

            let expected = Dependency.SetDisk(disk: disk,
                                              coordinate: .init(x: 0, y: 0),
                                              animated: true,
                                              completion: nil)

            XCTAssertEqual(paramater, expected)
            XCTAssertEqual(dependency.$updateBoard.calledCount, 1)

            paramater.completion?(true)
        }

        do {
            let paramater = try XCTUnwrap(dependency.$updateBoard.parameters.last)

            let expected = Dependency.SetDisk(disk: disk,
                                              coordinate: .init(x: 1, y: 1),
                                              animated: true,
                                              completion: nil)

            XCTAssertEqual(paramater, expected)
            XCTAssertEqual(dependency.$updateBoard.calledCount, 2)

            paramater.completion?(true)
        }

        XCTAssertEqual(isFinished, true)
    }
}

// - MARK: placeDisk

extension ReversiViewModelTests {

    func test_placeDisk_animatedがfalseの場合() throws {
        let viewModel = dependency.testTarget
        let logic = dependency.gameLogic

        let coordinate = Coordinate(x: 0, y: 1)
        let disk = Disk.dark

        logic._flippedDiskCoordinates = [coordinate]

        var isFinished: Bool?
        try viewModel.placeDisk(disk,
                                at: coordinate,
                                animated: false,
                                completion: { isFinished = $0 })

        let async = dependency.$async
        XCTAssertEqual(async.calledCount, 1)
        let completion = try XCTUnwrap(async.parameters.last)
        completion()

        let expected = Dependency.SetDisk(disk: disk,
                                          coordinate: coordinate,
                                          animated: false,
                                          completion: nil)
        let updateBoard = dependency.$updateBoard
        XCTAssertEqual(updateBoard.calledCount, 2)
        XCTAssertEqual(updateBoard.parameters, [expected, expected])

        XCTAssertEqual(isFinished, true)
    }

    func test_placeDisk_animatedがtrueの場合() throws {
        let viewModel = dependency.testTarget
        let logic = dependency.gameLogic

        let coordinate = Coordinate(x: 0, y: 1)
        let disk = Disk.dark

        logic._flippedDiskCoordinates = [coordinate]

        var isFinished: Bool?
        try viewModel.placeDisk(disk,
                                at: coordinate,
                                animated: true,
                                completion: { isFinished = $0 })

        let updateBoard = dependency.$updateBoard
        let expected = Dependency.SetDisk(disk: disk,
                                          coordinate: coordinate,
                                          animated: true,
                                          completion: nil)

        do {
            XCTAssertEqual(updateBoard.calledCount, 1)
            let parameter = try XCTUnwrap(updateBoard.parameters.last)
            parameter.completion?(false)

            XCTAssertEqual(parameter, expected)
        }

        do {
            let expected2 = Dependency.SetDisk(disk: disk,
                                               coordinate: coordinate,
                                               animated: false,
                                               completion: nil)
            XCTAssertEqual(updateBoard.calledCount, 3)
            XCTAssertEqual(updateBoard.parameters, [expected, expected2, expected2])
        }

        XCTAssertEqual(isFinished, false)
    }
}

extension ReversiViewModelTests {

    fileprivate final class Dependency {

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
        var updateBoard: Void

        @MockResponse<Int, Void>()
        var setPlayerDarkSelectedIndex: Void

        @MockResponse<Int, Void>()
        var setPlayerLightSelectedIndex: Void

        @MockResponse<Bool, Void>()
        var isPlayerDarkAnimating: Void

        @MockResponse<Bool, Void>()
        var isPlayerLightAnimating: Void

        @MockResponse<Void, Void>()
        var reset: Void

        @MockResponse<AsyncAfter, Void>()
        var asyncAfter: Void

        @MockResponse<() -> Void, Void>()
        var async: Void

        var gameDataCache: MockGameDataCache {
            gameLogic.cache
        }
        let gameLogic = MockGameLogic()

        private let messageDiskSize: CGFloat
        private let disposeBag = DisposeBag()

        private(set) lazy var testTarget = ReversiViewModel(
            messageDiskSize: messageDiskSize,
            asyncAfter: { [weak self] in self?._asyncAfter.respond(.init(time: $0, completion: $1)) },
            async: { [weak self] in self?._async.respond($0)  },
            logicFactory: MockGameLogicFactory(logic: gameLogic)
        )

        init(cells: [[GameData.Cell]], messageDiskSize: CGFloat) {
            self.messageDiskSize = messageDiskSize

            gameDataCache.$cells.accept(cells)

            testTarget.messageDiskSizeConstant
                .subscribe(onNext: { [weak self] in self?._setMessageDiskSizeConstant.respond($0) })
                .disposed(by: disposeBag)

            testTarget.messageDisk
                .subscribe(onNext: { [weak self] in self?._setMessageDisk.respond($0) })
                .disposed(by: disposeBag)

            testTarget.messageText
                .subscribe(onNext: { [weak self] in self?._setMessageText.respond($0) })
                .disposed(by: disposeBag)

            testTarget.resetBoard
                .subscribe(onNext: { [weak self] in self?._reset.respond() })
                .disposed(by: disposeBag)

            testTarget.showAlert
                .subscribe(onNext: { [weak self] in self?._showAlert.respond($0) })
                .disposed(by: disposeBag)

            testTarget.playerDarkCount
                .subscribe(onNext: { [weak self] in self?._setPlayerDarkCount.respond($0) })
                .disposed(by: disposeBag)

            testTarget.playerLightCount
                .subscribe(onNext: { [weak self] in self?._setPlayerLightCount.respond($0) })
                .disposed(by: disposeBag)

            testTarget.playerDarkSelectedIndex
                .subscribe(onNext: { [weak self] in self?._setPlayerDarkSelectedIndex.respond($0) })
                .disposed(by: disposeBag)

            testTarget.playerLightSelectedIndex
                .subscribe(onNext: { [weak self] in self?._setPlayerLightSelectedIndex.respond($0) })
                .disposed(by: disposeBag)

            testTarget.isPlayerDarkAnimating
                .subscribe(onNext: { [weak self] in self?._isPlayerDarkAnimating.respond($0) })
                .disposed(by: disposeBag)

            testTarget.isPlayerLightAnimating
                .subscribe(onNext: { [weak self] in self?._isPlayerLightAnimating.respond($0) })
                .disposed(by: disposeBag)

            testTarget.updateBoard
                .subscribe(onNext: { [weak self] value in
                    guard let me = self else {
                        return
                    }
                    me._updateBoard.respond(.init(disk: value.disk,
                                                  coordinate: value.coordinate,
                                                  animated: value.animated,
                                                  completion: value.completion))
                })
                .disposed(by: disposeBag)
        }
    }
}

extension ReversiViewModelTests.Dependency {
    struct AsyncAfter {
        let time: DispatchTime
        let completion: () -> Void
    }

    struct SetDisk: Equatable {
        let disk: Disk?
        let coordinate: Coordinate
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
            lhs.coordinate == rhs.coordinate &&
            lhs.animated == rhs.animated
    }
}
