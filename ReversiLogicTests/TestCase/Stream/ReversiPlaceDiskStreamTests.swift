import RxTest
import XCTest
@testable import ReversiLogic

final class ReversiPlaceDiskStreamTests: XCTestCase {

    private var dependency: Dependency!

    override func setUp() {
        self.dependency = Dependency()
    }

    func test_handleDiskWithCoordinate() throws {
        let stream = dependency.testTarget
        let store = dependency.store
        let flippedDiskCoordinates = dependency.flippedDiskCoordinates
        let animateSettingDisks = dependency.animateSettingDisks

        store.$placeDiskCanceller.accept(Canceller {})

        let coordinate = Coordinate(x: 0, y: 1)
        let disk = Disk.dark
        flippedDiskCoordinates.callAsFunctionResponse = [coordinate]

        let didUpdateDisk = Watcher(stream.output.didUpdateDisk)
        stream.input.handleDiskWithCoordinate((disk, coordinate))
        animateSettingDisks._callAsFunction.onNext(true)

        XCTAssertEqual(didUpdateDisk.calledCount, 1)
        XCTAssertEqual(didUpdateDisk.parameters, [true])

        let callAsFunction = animateSettingDisks.$_callAsFunction
        XCTAssertEqual(callAsFunction.parameters, [.init(disk: disk,
                                                         coordinates: [coordinate, coordinate])])
    }

    func test_refreshAllDisk() throws {
        let stream = dependency.testTarget
        let store = dependency.store

        store.$placeDiskCanceller.accept(Canceller {})

        let coordinates = [Coordinate(x: 0, y: 0), Coordinate(x: 0, y: 1)]
        let disk = Disk.dark
        store.$cells.accept([coordinates.map { GameData.Cell(coordinate: $0, disk: disk) }])

        let didRefreshAllDisk = Watcher(stream.output.didRefreshAllDisk)
        stream.input.refreshAllDisk(())
        dependency.setDisk._callAsFunction.onNext(true)
        dependency.setDisk._callAsFunction.onNext(true)

        XCTAssertEqual(didRefreshAllDisk.calledCount, 1)
        XCTAssertFalse(didRefreshAllDisk.parameters.isEmpty)
    }
}

extension ReversiPlaceDiskStreamTests {

    private final class  Dependency {

        let store = MockGameStore()
        let actionCreator = MockGameActionCreator()

        let flippedDiskCoordinates = MockFlippedDiskCoordinates()
        let setDisk = MockSetDisk()
        let animateSettingDisks = MockAnimateSettingDisks()

        let testScheduler = TestScheduler(initialClock: 0)

        let testTarget: ReversiPlaceDiskStream

        init() {
            self.testTarget = ReversiPlaceDiskStream(
                actionCreator: actionCreator,
                store: store,
                mainAsyncScheduler: testScheduler,
                flippedDiskCoordinates: flippedDiskCoordinates,
                setDisk: setDisk,
                animateSettingDisks: animateSettingDisks
            )
        }
    }
}

//// - MARK: animateSettingDisks
//
//extension ReversiViewModelTests {
//
//    func test_animateSettingDisks_coordinatesが0件の場合() {
//        let logic = dependency.gameLogic
//        let state = dependency.state
//
//        let isFinished = BehaviorRelay<Bool?>(value: nil)
//        let disposable = ReversiViewModel.animateSettingDisks(at: [], to: .dark, logic: logic, state: state)
//            .asObservable()
//            .bind(to: isFinished)
//        defer { disposable.dispose() }
//
//        XCTAssertEqual(isFinished.value, true)
//    }
//
//    func test_animateSettingDisks_animationCancellerがnilの場合() {
//        let logic = dependency.gameLogic
//        let state = dependency.state
//        let coordinates = [Coordinate(x: 0, y: 0), Coordinate(x: 1, y: 1)]
//        let disk = Disk.dark
//        logic.placeDiskCanceller = nil
//
//        let error = BehaviorRelay<ReversiViewModel.Error?>(value: nil)
//        let disposable = ReversiViewModel.animateSettingDisks(at: coordinates, to: disk, logic: logic, state: state)
//            .asObservable()
//            .flatMap { _ in Observable<ReversiViewModel.Error?>.empty() }
//            .catchError { Observable.just($0 as? ReversiViewModel.Error) }
//            .bind(to: error)
//        defer { disposable.dispose() }
//
//        XCTAssertEqual(error.value, .animationCancellerReleased)
//    }
//
//    func test_animateSettingDisks_animationCancellerを途中でキャンセルした場合() throws {
//        let logic = dependency.gameLogic
//        let state = dependency.state
//        let coordinates = [Coordinate(x: 0, y: 0), Coordinate(x: 1, y: 1)]
//        let disk = Disk.dark
//        logic.placeDiskCanceller = Canceller({})
//
//        let error = BehaviorRelay<ReversiViewModel.Error?>(value: nil)
//        let disposable = ReversiViewModel.animateSettingDisks(at: coordinates, to: disk, logic: logic, state: state)
//            .asObservable()
//            .flatMap { _ in Observable<ReversiViewModel.Error?>.empty() }
//            .catchError { Observable.just($0 as? ReversiViewModel.Error) }
//            .bind(to: error)
//        defer { disposable.dispose() }
//
//        let expected = Dependency.SetDisk(disk: disk,
//                                          coordinate: .init(x: 0, y: 0),
//                                          animated: true,
//                                          completion: nil)
//
//        let paramater = try XCTUnwrap(dependency.$updateBoard.parameters.first)
//
//        XCTAssertEqual(paramater, expected)
//        XCTAssertEqual(dependency.$updateBoard.calledCount, 1)
//
//        logic.placeDiskCanceller?.cancel()
//        paramater.completion?(false)
//
//        XCTAssertEqual(error.value, .animationCancellerCancelled)
//    }
//
//    func test_animateSettingDisks_setDiskのfinishedがfalseの場合() throws {
//        let logic = dependency.gameLogic
//        let state = dependency.state
//        let coordinates = [Coordinate(x: 0, y: 0), Coordinate(x: 1, y: 1)]
//        let disk = Disk.dark
//        logic.placeDiskCanceller = Canceller({})
//
//        let isFinished = BehaviorRelay<Bool?>(value: nil)
//        let disposable = ReversiViewModel.animateSettingDisks(at: coordinates, to: disk, logic: logic, state: state)
//            .asObservable()
//            .bind(to: isFinished)
//        defer { disposable.dispose() }
//
//        let expected = Dependency.SetDisk(disk: disk,
//                                          coordinate: .init(x: 0, y: 0),
//                                          animated: true,
//                                          completion: nil)
//
//        let updateBoard = dependency.$updateBoard
//        do {
//            let paramater = try XCTUnwrap(updateBoard.parameters.first)
//
//            XCTAssertEqual(paramater, expected)
//            XCTAssertEqual(updateBoard.calledCount, 1)
//
//            paramater.completion?(false)
//        }
//
//        do {
//            updateBoard.parameters.forEach { $0.completion?(false) }
//
//            let expected1 = Dependency.SetDisk(disk: disk,
//                                               coordinate: .init(x: 0, y: 0),
//                                               animated: false,
//                                               completion: nil)
//
//            let expected2 = Dependency.SetDisk(disk: disk,
//                                               coordinate: .init(x: 1, y: 1),
//                                               animated: false,
//                                               completion: nil)
//
//            XCTAssertEqual(updateBoard.parameters, [expected, expected1, expected2])
//            XCTAssertEqual(updateBoard.calledCount, 3)
//        }
//
//        XCTAssertEqual(isFinished.value, false)
//    }
//
//    func test_animateSettingDisks_setDiskのfinishedがtrueの場合() throws {
//        let logic = dependency.gameLogic
//        let state = dependency.state
//        let coordinates = [Coordinate(x: 0, y: 0), Coordinate(x: 1, y: 1)]
//        let disk = Disk.dark
//        logic.placeDiskCanceller = Canceller({})
//
//        let isFinished = BehaviorRelay<Bool?>(value: nil)
//        let disposable = ReversiViewModel.animateSettingDisks(at: coordinates, to: disk, logic: logic, state: state)
//            .asObservable()
//            .bind(to: isFinished)
//        defer { disposable.dispose() }
//
//        do {
//            let paramater = try XCTUnwrap(dependency.$updateBoard.parameters.last)
//
//            let expected = Dependency.SetDisk(disk: disk,
//                                              coordinate: .init(x: 0, y: 0),
//                                              animated: true,
//                                              completion: nil)
//
//            XCTAssertEqual(paramater, expected)
//            XCTAssertEqual(dependency.$updateBoard.calledCount, 1)
//
//            paramater.completion?(true)
//        }
//
//        do {
//            let paramater = try XCTUnwrap(dependency.$updateBoard.parameters.last)
//
//            let expected = Dependency.SetDisk(disk: disk,
//                                              coordinate: .init(x: 1, y: 1),
//                                              animated: true,
//                                              completion: nil)
//
//            XCTAssertEqual(paramater, expected)
//            XCTAssertEqual(dependency.$updateBoard.calledCount, 2)
//
//            paramater.completion?(true)
//        }
//
//        XCTAssertEqual(isFinished.value, true)
//    }
//}

//    func test_nextTurn_statusがlightのときに_darkの有効な配置がある場合() {
//        let store = dependency.store
//        store.$status.accept(.turn(.light))
//
//        let logic = dependency.gameLogic
//        logic._validMovekForDark = [Coordinate(x: 0, y: 0)]
//
//        dependency.state.nextTurn.accept(())
//
//        XCTAssertEqual(logic.$_setStatus.parameters, [.turn(.dark)])
//    }

//    func test_nextTurn_statusがlightのときに_darkの有効な配置はないが_lightの有効な配置がある場合() {
//        let store = dependency.store
//        store.$status.accept(.turn(.light))
//
//        let logic = dependency.gameLogic
//        logic._validMovekForDark = []
//        logic._validMovekForLight = [Coordinate(x: 0, y: 0)]
//
//        dependency.state.nextTurn.accept(())
//
//        XCTAssertEqual(logic.$_setStatus.parameters, [.turn(.dark)])
//
//        let showAlert = dependency.$showAlert
//        XCTAssertEqual(showAlert.calledCount, 1)
//        XCTAssertEqual(showAlert.parameters, [.pass(dismissHandler: {})])
//    }
//
//    func test_nextTurn_statuがlightのときに_darkもlightの有効な配置はない場合() {
//        let store = dependency.store
//        store.$status.accept(.turn(.light))
//
//        let logic = dependency.gameLogic
//        logic._validMovekForDark = []
//        logic._validMovekForLight = []
//
//        dependency.state.nextTurn.accept(())
//
//        XCTAssertEqual(logic.$_setStatus.parameters, [.gameOver])
//    }
//
//    func test_handleReset() {
//        let viewModel = dependency.testTarget
//
//        viewModel.input.handleReset(())
//
//        let showAlert = dependency.$showAlert
//        XCTAssertEqual(showAlert.calledCount, 1)
//        XCTAssertEqual(showAlert.parameters, [.reset(okHandler: {})])
//    }
//}
//
