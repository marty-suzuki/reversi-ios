import RxRelay
import RxSwift
import RxTest
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
        let store = dependency.store
        store.$playerDark.accept(.manual)
        let turn = Disk.dark
        store.$status.accept(.turn(turn))
        let logic = dependency.gameLogic
        logic._validMovekForDark = [Coordinate(x: 0, y: 0)]
        let waitForPlayer = logic.$_waitForPlayer

        viewModel.input.viewDidAppear(())
        XCTAssertEqual(waitForPlayer.calledCount, 1)

        viewModel.input.viewDidAppear(())
        XCTAssertEqual(waitForPlayer.calledCount, 1)
    }

    func test_status_gameOverじゃない場合() {
        let expectedSize = CGFloat(arc4random() % 100)
        self.dependency = Dependency(cells: GameData.initial.cells, messageDiskSize: expectedSize)

        let expectedTurn = Disk.light
        let store = dependency.store
        store.$status.accept(.turn(expectedTurn))

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

        let store = dependency.store
        store.$sideWithMoreDisks.accept(expectedDisk)
        store.$status.accept(.gameOver)

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

        let store = dependency.store
        store.$sideWithMoreDisks.accept(nil)
        store.$status.accept(.gameOver)

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
        let store = dependency.store
        store.$countOfDark.accept(darkCount)
        store.$countOfLight.accept(lightCount)

        dependency.state.updateCount.accept(())

        let setPlayerDarkCount = dependency.$setPlayerDarkCount
        XCTAssertEqual(setPlayerDarkCount.calledCount, 1)
        XCTAssertEqual(setPlayerDarkCount.parameters, ["\(darkCount)"])

        let setPlayerLightCount = dependency.$setPlayerLightCount
        XCTAssertEqual(setPlayerLightCount.calledCount, 1)
        XCTAssertEqual(setPlayerLightCount.parameters, ["\(lightCount)"])
    }
    func test_nextTurn_statusがlightのときに_darkの有効な配置がある場合() {
        let store = dependency.store
        store.$status.accept(.turn(.light))

        let logic = dependency.gameLogic
        logic._validMovekForDark = [Coordinate(x: 0, y: 0)]

        dependency.state.nextTurn.accept(())

        XCTAssertEqual(logic.$_setStatus.parameters, [.turn(.dark)])
    }

    func test_nextTurn_statusがlightのときに_darkの有効な配置はないが_lightの有効な配置がある場合() {
        let store = dependency.store
        store.$status.accept(.turn(.light))

        let logic = dependency.gameLogic
        logic._validMovekForDark = []
        logic._validMovekForLight = [Coordinate(x: 0, y: 0)]

        dependency.state.nextTurn.accept(())

        XCTAssertEqual(logic.$_setStatus.parameters, [.turn(.dark)])

        let showAlert = dependency.$showAlert
        XCTAssertEqual(showAlert.calledCount, 1)
        XCTAssertEqual(showAlert.parameters, [.pass(dismissHandler: {})])
    }

    func test_nextTurn_statuがlightのときに_darkもlightの有効な配置はない場合() {
        let store = dependency.store
        store.$status.accept(.turn(.light))

        let logic = dependency.gameLogic
        logic._validMovekForDark = []
        logic._validMovekForLight = []

        dependency.state.nextTurn.accept(())

        XCTAssertEqual(logic.$_setStatus.parameters, [.gameOver])
    }

    func test_handleReset() {
        let viewModel = dependency.testTarget

        viewModel.input.handleReset(())

        let showAlert = dependency.$showAlert
        XCTAssertEqual(showAlert.calledCount, 1)
        XCTAssertEqual(showAlert.parameters, [.reset(okHandler: {})])
    }
}

// - MARK: animateSettingDisks

extension ReversiViewModelTests {

    func test_animateSettingDisks_coordinatesが0件の場合() {
        let logic = dependency.gameLogic
        let state = dependency.state

        let isFinished = BehaviorRelay<Bool?>(value: nil)
        let disposable = ReversiViewModel.animateSettingDisks(at: [], to: .dark, logic: logic, state: state)
            .asObservable()
            .bind(to: isFinished)
        defer { disposable.dispose() }

        XCTAssertEqual(isFinished.value, true)
    }

    func test_animateSettingDisks_animationCancellerがnilの場合() {
        let logic = dependency.gameLogic
        let state = dependency.state
        let coordinates = [Coordinate(x: 0, y: 0), Coordinate(x: 1, y: 1)]
        let disk = Disk.dark
        logic.placeDiskCanceller = nil

        let error = BehaviorRelay<ReversiViewModel.Error?>(value: nil)
        let disposable = ReversiViewModel.animateSettingDisks(at: coordinates, to: disk, logic: logic, state: state)
            .asObservable()
            .flatMap { _ in Observable<ReversiViewModel.Error?>.empty() }
            .catchError { Observable.just($0 as? ReversiViewModel.Error) }
            .bind(to: error)
        defer { disposable.dispose() }

        XCTAssertEqual(error.value, .animationCancellerReleased)
    }

    func test_animateSettingDisks_animationCancellerを途中でキャンセルした場合() throws {
        let logic = dependency.gameLogic
        let state = dependency.state
        let coordinates = [Coordinate(x: 0, y: 0), Coordinate(x: 1, y: 1)]
        let disk = Disk.dark
        logic.placeDiskCanceller = Canceller({})

        let error = BehaviorRelay<ReversiViewModel.Error?>(value: nil)
        let disposable = ReversiViewModel.animateSettingDisks(at: coordinates, to: disk, logic: logic, state: state)
            .asObservable()
            .flatMap { _ in Observable<ReversiViewModel.Error?>.empty() }
            .catchError { Observable.just($0 as? ReversiViewModel.Error) }
            .bind(to: error)
        defer { disposable.dispose() }

        let expected = Dependency.SetDisk(disk: disk,
                                          coordinate: .init(x: 0, y: 0),
                                          animated: true,
                                          completion: nil)

        let paramater = try XCTUnwrap(dependency.$updateBoard.parameters.first)

        XCTAssertEqual(paramater, expected)
        XCTAssertEqual(dependency.$updateBoard.calledCount, 1)

        logic.placeDiskCanceller?.cancel()
        paramater.completion?(false)

        XCTAssertEqual(error.value, .animationCancellerCancelled)
    }

    func test_animateSettingDisks_setDiskのfinishedがfalseの場合() throws {
        let logic = dependency.gameLogic
        let state = dependency.state
        let coordinates = [Coordinate(x: 0, y: 0), Coordinate(x: 1, y: 1)]
        let disk = Disk.dark
        logic.placeDiskCanceller = Canceller({})

        let isFinished = BehaviorRelay<Bool?>(value: nil)
        let disposable = ReversiViewModel.animateSettingDisks(at: coordinates, to: disk, logic: logic, state: state)
            .asObservable()
            .bind(to: isFinished)
        defer { disposable.dispose() }

        let expected = Dependency.SetDisk(disk: disk,
                                          coordinate: .init(x: 0, y: 0),
                                          animated: true,
                                          completion: nil)

        let updateBoard = dependency.$updateBoard
        do {
            let paramater = try XCTUnwrap(updateBoard.parameters.first)

            XCTAssertEqual(paramater, expected)
            XCTAssertEqual(updateBoard.calledCount, 1)

            paramater.completion?(false)
        }

        do {
            updateBoard.parameters.forEach { $0.completion?(false) }

            let expected1 = Dependency.SetDisk(disk: disk,
                                               coordinate: .init(x: 0, y: 0),
                                               animated: false,
                                               completion: nil)

            let expected2 = Dependency.SetDisk(disk: disk,
                                               coordinate: .init(x: 1, y: 1),
                                               animated: false,
                                               completion: nil)

            XCTAssertEqual(updateBoard.parameters, [expected, expected1, expected2])
            XCTAssertEqual(updateBoard.calledCount, 3)
        }

        XCTAssertEqual(isFinished.value, false)
    }

    func test_animateSettingDisks_setDiskのfinishedがtrueの場合() throws {
        let logic = dependency.gameLogic
        let state = dependency.state
        let coordinates = [Coordinate(x: 0, y: 0), Coordinate(x: 1, y: 1)]
        let disk = Disk.dark
        logic.placeDiskCanceller = Canceller({})

        let isFinished = BehaviorRelay<Bool?>(value: nil)
        let disposable = ReversiViewModel.animateSettingDisks(at: coordinates, to: disk, logic: logic, state: state)
            .asObservable()
            .bind(to: isFinished)
        defer { disposable.dispose() }

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

        XCTAssertEqual(isFinished.value, true)
    }
}

// - MARK: placeDisk

extension ReversiViewModelTests {

    func test_placeDisk_animatedがfalseの場合() throws {
        let logic = dependency.gameLogic
        let state = dependency.state
        let extra = dependency.extra
        let scheduler = dependency.testScheduler

        let coordinate = Coordinate(x: 0, y: 1)
        let disk = Disk.dark

        logic._flippedDiskCoordinates = [coordinate]

        let isFinished = BehaviorRelay<Bool?>(value: nil)
        let disposable = ReversiViewModel.placeDisk(disk, at: coordinate, animated: false, logic: logic, state: state, extra: extra)
            .asObservable()
            .bind(to: isFinished)
        defer { disposable.dispose() }

        scheduler.advanceTo(scheduler.clock + 200)

        let updateBoard = dependency.$updateBoard
        updateBoard.parameters.forEach { $0.completion?(false) }

        let expected = Dependency.SetDisk(disk: disk,
                                          coordinate: coordinate,
                                          animated: false,
                                          completion: nil)

        XCTAssertEqual(updateBoard.calledCount, 2)
        XCTAssertEqual(updateBoard.parameters, [expected, expected])

        XCTAssertEqual(isFinished.value, true)
    }

    func test_placeDisk_animatedがtrueの場合() throws {
        let logic = dependency.gameLogic
        let state = dependency.state
        let extra = dependency.extra
        let coordinate = Coordinate(x: 0, y: 1)
        let disk = Disk.dark

        logic._flippedDiskCoordinates = [coordinate]

        let isFinished = BehaviorRelay<Bool?>(value: nil)
        let disposable = ReversiViewModel.placeDisk(disk, at: coordinate, animated: true, logic: logic, state: state, extra: extra)
            .asObservable()
            .bind(to: isFinished)
        defer { disposable.dispose() }

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
            updateBoard.parameters.forEach { $0.completion?(false) }

            let expected2 = Dependency.SetDisk(disk: disk,
                                               coordinate: coordinate,
                                               animated: false,
                                               completion: nil)
            XCTAssertEqual(updateBoard.calledCount, 3)
            XCTAssertEqual(updateBoard.parameters, [expected, expected2, expected2])
        }

        XCTAssertEqual(isFinished.value, false)
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

        var store: MockGameStore {
            gameLogic.store
        }
        let gameLogic = MockGameLogic()
        let state = ReversiViewModel.State()
        let testScheduler = TestScheduler(initialClock: 0)
        private(set) lazy var extra = ReversiViewModel.Extra(
            messageDiskSize: messageDiskSize,
            mainAsyncScheduler: testScheduler,
            mainScheduler: testScheduler,
            logic: gameLogic
        )

        private let messageDiskSize: CGFloat
        private let disposeBag = DisposeBag()

        private(set) lazy var testTarget = ReversiViewModel(
            input: ReversiViewModel.Input(),
            state: state,
            extra: extra
        )

        init(cells: [[GameData.Cell]], messageDiskSize: CGFloat) {
            self.messageDiskSize = messageDiskSize

            store.$cells.accept(cells)

            testTarget.output.messageDiskSizeConstant
                .subscribe(onNext: { [weak self] in self?._setMessageDiskSizeConstant.respond($0) })
                .disposed(by: disposeBag)

            testTarget.output.messageDisk
                .subscribe(onNext: { [weak self] in self?._setMessageDisk.respond($0) })
                .disposed(by: disposeBag)

            testTarget.output.messageText
                .subscribe(onNext: { [weak self] in self?._setMessageText.respond($0) })
                .disposed(by: disposeBag)

            testTarget.output.resetBoard
                .subscribe(onNext: { [weak self] in self?._reset.respond() })
                .disposed(by: disposeBag)

            testTarget.output.showAlert
                .subscribe(onNext: { [weak self] in self?._showAlert.respond($0) })
                .disposed(by: disposeBag)

            testTarget.output.playerDarkCount
                .subscribe(onNext: { [weak self] in self?._setPlayerDarkCount.respond($0) })
                .disposed(by: disposeBag)

            testTarget.output.playerLightCount
                .subscribe(onNext: { [weak self] in self?._setPlayerLightCount.respond($0) })
                .disposed(by: disposeBag)

            testTarget.output.playerDarkSelectedIndex
                .subscribe(onNext: { [weak self] in self?._setPlayerDarkSelectedIndex.respond($0) })
                .disposed(by: disposeBag)

            testTarget.output.playerLightSelectedIndex
                .subscribe(onNext: { [weak self] in self?._setPlayerLightSelectedIndex.respond($0) })
                .disposed(by: disposeBag)

            testTarget.output.isPlayerDarkAnimating
                .subscribe(onNext: { [weak self] in self?._isPlayerDarkAnimating.respond($0) })
                .disposed(by: disposeBag)

            testTarget.output.isPlayerLightAnimating
                .subscribe(onNext: { [weak self] in self?._isPlayerLightAnimating.respond($0) })
                .disposed(by: disposeBag)

            testTarget.output.updateBoard
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
