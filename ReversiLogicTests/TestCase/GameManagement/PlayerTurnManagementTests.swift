import RxRelay
import RxTest
import TestModule
import XCTest
@testable import ReversiLogic

final class PlayerTurnManagementTests: XCTestCase {
    private var dependency: Dependency!

    override func setUp() {
        self.dependency = Dependency()
    }

    func test_callAsFunction_isDiskPlacingがfalseで_playerOfCurrentTurnがmanualで_statusがturnで_handleSelectedCoordinateが発火() throws {
        let management = dependency.testTarget
        let store = dependency.store
        let handleSelectedCoordinate = dependency.handleSelectedCoordinate

        let disk = Disk.dark
        store.$isDiskPlacing.accept(false)
        store.$playerOfCurrentTurn.accept(.manual)
        store.$status.accept(.turn(disk))

        let result = Watcher(management.callAsFunction(
            waitForPlayer: dependency.waitForPlayer.asObservable(),
            setPlayerForDiskWithIndex: dependency.setPlayerForDiskWithIndex.asObservable(),
            handleSelectedCoordinate: handleSelectedCoordinate.asObservable(),
            save: dependency.save,
            willTurnDiskOfComputer: dependency.willTurnDiskOfComputer,
            didTurnDiskOfComputer: dependency.didTurnDiskOfComputer
            ).asObservable()
        )

        let coordinate = Coordinate(x: 0, y: 0)
        handleSelectedCoordinate.accept(coordinate)

        XCTAssertEqual(result.calledCount, 1)
        let parameter = try XCTUnwrap(result.parameters.last)
        XCTAssertEqual(parameter.0, disk)
        XCTAssertEqual(parameter.1, coordinate)
    }
}

extension PlayerTurnManagementTests {
    private final class Dependency {
        let testTarget: PlayerTurnManagement

        let store = MockGameStore()
        let actionCreator = MockGameActionCreator()
        let validMoves = MockValidMoves()
        let scheduler = TestScheduler(initialClock: 0)

        let waitForPlayer = PublishRelay<Void>()
        let setPlayerForDiskWithIndex = PublishRelay<(Disk, Int)>()
        let handleSelectedCoordinate = PublishRelay<Coordinate>()
        let save = PublishRelay<Void>()
        let willTurnDiskOfComputer = PublishRelay<Disk>()
        let didTurnDiskOfComputer = PublishRelay<Disk>()

        init() {
            self.testTarget = PlayerTurnManagement(
                store: store,
                actionCreator: actionCreator,
                validMoves: validMoves,
                mainScheduler: scheduler
            )
        }
    }
}
