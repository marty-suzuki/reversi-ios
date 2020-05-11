import RxTest
import TestModule
import XCTest
@testable import ReversiLogic

final class ReversiManagementStreamTests: XCTestCase {

    private var dependency: Dependency!

    override func setUp() {
        self.dependency = Dependency()
    }

    func test_output_didUpdateDisk() throws {
        let stream = dependency.testTarget
        let placeDisk = dependency.placeDisk
        let playerTurnManagement = dependency.playerTurnManagement

        let coordinate = Coordinate(x: 0, y: 1)
        let disk = Disk.dark
        let finished = true

        let nextTurn = Watcher(dependency.state.nextTurn)
        let save = Watcher(dependency.state.save)

        let didUpdateDisk = Watcher(stream.output.didUpdateDisk)
        playerTurnManagement._callAsFunction.onNext((disk, coordinate))
        placeDisk._callAsFunction.onNext(finished)

        XCTAssertEqual(didUpdateDisk.calledCount, 1)
        XCTAssertEqual(didUpdateDisk.parameters, [finished])

        let callAsFunction = placeDisk.$_callAsFunction
        XCTAssertEqual(callAsFunction.parameters, [.init(disk: disk,
                                                         coordinate: coordinate,
                                                         animated: true)])

        XCTAssertEqual(nextTurn.calledCount, 1)
        XCTAssertFalse(nextTurn.parameters.isEmpty)

        XCTAssertEqual(save.calledCount, 1)
        XCTAssertFalse(save.parameters.isEmpty)
    }

    func test_output_refreshAllDisk() throws {
        let stream = dependency.testTarget
        let store = dependency.store

        store.$placeDiskCanceller.accept(Canceller {})

        let coordinates = [Coordinate(x: 0, y: 0), Coordinate(x: 0, y: 1)]
        let disk = Disk.dark
        store.$cells.accept([coordinates.map { GameData.Cell(coordinate: $0, disk: disk) }])

        let didRefreshAllDisk = Watcher(stream.output.didRefreshAllDisk)
        store.$loaded.accept(())
        dependency.setDisk._callAsFunction.onNext(true)
        dependency.setDisk._callAsFunction.onNext(true)

        XCTAssertEqual(didRefreshAllDisk.calledCount, 1)
        XCTAssertFalse(didRefreshAllDisk.parameters.isEmpty)
    }

    func test_state_waitForPlayer_nextTurnResponse() {
        let nextTurnManagement = dependency.nextTurnManagement
        let waitForPlayer = Watcher(dependency.state.waitForPlayer)

        nextTurnManagement._callAsFunction.onNext(.gameOver)
        XCTAssertEqual(waitForPlayer.calledCount, 0)
        XCTAssertTrue(waitForPlayer.parameters.isEmpty)

        nextTurnManagement._callAsFunction.onNext(.noValidMoves(.gameOver))
        XCTAssertEqual(waitForPlayer.calledCount, 0)
        XCTAssertTrue(waitForPlayer.parameters.isEmpty)

        nextTurnManagement._callAsFunction.onNext(.validMoves(.gameOver))
        XCTAssertEqual(waitForPlayer.calledCount, 1)
        XCTAssertFalse(waitForPlayer.parameters.isEmpty)
    }
}

extension ReversiManagementStreamTests {

    private final class  Dependency {

        let input = ReversiManagementStream.Input()
        let state = ReversiManagementStream.State()
        let store = MockGameStore()
        let actionCreator = MockGameActionCreator()

        let flippedDiskCoordinates = MockFlippedDiskCoordinates()
        let setDisk = MockSetDisk()
        let animateSettingDisks = MockAnimateSettingDisks()
        let placeDisk = MockPlaceDisk()
        let validMoves = MockValidMoves()
        let nextTurnManagement = MockNextTurnManagement()
        let playerTurnManagement = MockPlayerTurnManagement()
        let alertManagement = MockAlertManagement()

        let testScheduler = TestScheduler(initialClock: 0)

        let testTarget: ReversiManagementStream

        init() {
            self.testTarget = ReversiManagementStream(
                input: input,
                state: state,
                extra: .init(store: store,
                             actionCreator: actionCreator,
                             mainScheduler: testScheduler,
                             validMoves: validMoves,
                             setDisk: setDisk,
                             placeDisk: placeDisk,
                             nextTurnManagement: nextTurnManagement,
                             playerTurnManagement: playerTurnManagement,
                             alertManagement: alertManagement)
            )
        }
    }
}
