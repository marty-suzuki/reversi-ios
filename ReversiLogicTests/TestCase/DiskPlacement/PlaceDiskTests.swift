import RxRelay
import RxTest
import XCTest
@testable import ReversiLogic

final class PlaceDiskTests: XCTestCase {
    private var dependency: Dependency!

    override func setUp() {
        self.dependency = Dependency()
    }

    func test_animatedがfalseで_flippedDiskCoordinatesが1件以上() {
        let placeDisk = dependency.testTarget
        let flippedDiskCoordinates = dependency.flippedDiskCoordinates
        let setDisk = dependency.setDisk
        let scheduler = dependency.testScheduler

        let flippedCoordinate = Coordinate(x: 0, y: 1)
        let disk = Disk.dark
        let coordiate = Coordinate(x: 0, y: 0)
        let finshed = placeDisk(disk,
                                at: coordiate,
                                animated: false,
                                updateDisk: dependency.updateDisk)
            .asObservable()
        let result = Watcher(finshed)
        flippedDiskCoordinates._callAsFunction.onNext([flippedCoordinate])
        scheduler.start()
        setDisk._callAsFunction.onNext(true)
        setDisk._callAsFunction.onNext(true)

        XCTAssertEqual(result.calledCount, 1)
        XCTAssertEqual(result.parameters, [true])
        XCTAssertEqual(setDisk.$_callAsFunction.calledCount, 2)

        let expectedSetDisks = [
            MockSetDisk.Parameters(disk: disk, coordinate: coordiate, animated: false),
            MockSetDisk.Parameters(disk: disk, coordinate: flippedCoordinate, animated: false),
        ]
        XCTAssertEqual(setDisk.$_callAsFunction.parameters, expectedSetDisks)
    }

    func test_animatedがtrueで_flippedDiskCoordinatesが1件以上で_placeDiskCancellerがnil() throws {
        let placeDisk = dependency.testTarget
        let flippedDiskCoordinates = dependency.flippedDiskCoordinates
        let animateSettingDisks = dependency.animateSettingDisks
        let actionCreator = dependency.actionCreator
        let store = dependency.store

        let flippedCoordinate = Coordinate(x: 0, y: 1)
        store.$placeDiskCanceller.accept(nil)

        let disk = Disk.dark
        let coordiate = Coordinate(x: 0, y: 0)
        let finshed = placeDisk(disk,
                                at: coordiate,
                                animated: true,
                                updateDisk: dependency.updateDisk)
            .asObservable()

        let result = Watcher(finshed)
        flippedDiskCoordinates._callAsFunction.onNext([flippedCoordinate])

        XCTAssertEqual(actionCreator.$_setPlaceDiskCanceller.calledCount, 1)
        let placeDiskCanceller = try XCTUnwrap(actionCreator.$_setPlaceDiskCanceller.parameters.first)
        XCTAssertNotNil(placeDiskCanceller)
        XCTAssertEqual(animateSettingDisks.$_callAsFunction.calledCount, 1)
        let expextedAnimateSettingDisks = [
            MockAnimateSettingDisks.Parameters(disk: disk,
                                               coordinates: [coordiate, flippedCoordinate])
        ]
        XCTAssertEqual(animateSettingDisks.$_callAsFunction.parameters, expextedAnimateSettingDisks)

        animateSettingDisks._callAsFunction.onNext(true)

        XCTAssertEqual(result.calledCount, 1)
        let error = try XCTUnwrap(result.errors.first as? PlaceDisk.Error)
        XCTAssertEqual(error, .animationCancellerReleased)
    }

    func test_animatedがtrueで_flippedDiskCoordinatesが1件以上で_placeDiskCancellerがnilではなく_cancellerがcancelされている() throws {
        let placeDisk = dependency.testTarget
        let flippedDiskCoordinates = dependency.flippedDiskCoordinates
        let animateSettingDisks = dependency.animateSettingDisks
        let actionCreator = dependency.actionCreator
        let store = dependency.store

        let flippedCoordinate = Coordinate(x: 0, y: 1)
        let canceller = Canceller({})
        canceller.cancel()
        store.$placeDiskCanceller.accept(canceller)

        let disk = Disk.dark
        let coordiate = Coordinate(x: 0, y: 0)
        let finshed = placeDisk(disk,
                                at: coordiate,
                                animated: true,
                                updateDisk: dependency.updateDisk)
            .asObservable()

        let result = Watcher(finshed)
        flippedDiskCoordinates._callAsFunction.onNext([flippedCoordinate])

        XCTAssertEqual(actionCreator.$_setPlaceDiskCanceller.calledCount, 1)
        let placeDiskCanceller = try XCTUnwrap(actionCreator.$_setPlaceDiskCanceller.parameters.first)
        XCTAssertNotNil(placeDiskCanceller)
        XCTAssertEqual(animateSettingDisks.$_callAsFunction.calledCount, 1)
        let expextedAnimateSettingDisks = [
            MockAnimateSettingDisks.Parameters(disk: disk,
                                               coordinates: [coordiate, flippedCoordinate])
        ]
        XCTAssertEqual(animateSettingDisks.$_callAsFunction.parameters, expextedAnimateSettingDisks)

        animateSettingDisks._callAsFunction.onNext(true)

        XCTAssertEqual(result.calledCount, 1)
        let error = try XCTUnwrap(result.errors.first as? PlaceDisk.Error)
        XCTAssertEqual(error, .animationCancellerCancelled)
    }

    func test_animatedがtrueで_flippedDiskCoordinatesが1件以上で_placeDiskCancellerがnilではなく_cancellerがcancelされていない() throws {
        let placeDisk = dependency.testTarget
        let flippedDiskCoordinates = dependency.flippedDiskCoordinates
        let animateSettingDisks = dependency.animateSettingDisks
        let actionCreator = dependency.actionCreator
        let store = dependency.store

        let flippedCoordinate = Coordinate(x: 0, y: 1)
        let canceller = Canceller({})
        store.$placeDiskCanceller.accept(canceller)

        let expectedFinished = true
        let disk = Disk.dark
        let coordiate = Coordinate(x: 0, y: 0)
        let finshed = placeDisk(disk,
                                at: coordiate,
                                animated: true,
                                updateDisk: dependency.updateDisk)
            .asObservable()

        let result = Watcher(finshed)
        flippedDiskCoordinates._callAsFunction.onNext([flippedCoordinate])

        do {
            XCTAssertEqual(actionCreator.$_setPlaceDiskCanceller.calledCount, 1)
            let placeDiskCanceller = try XCTUnwrap(actionCreator.$_setPlaceDiskCanceller.parameters.first)
            XCTAssertNotNil(placeDiskCanceller)
        }
        XCTAssertEqual(animateSettingDisks.$_callAsFunction.calledCount, 1)
        let expextedAnimateSettingDisks = [
            MockAnimateSettingDisks.Parameters(disk: disk,
                                               coordinates: [coordiate, flippedCoordinate])
        ]
        XCTAssertEqual(animateSettingDisks.$_callAsFunction.parameters, expextedAnimateSettingDisks)

        animateSettingDisks._callAsFunction.onNext(expectedFinished)

        XCTAssertEqual(result.calledCount, 1)
        XCTAssertEqual(result.parameters, [expectedFinished])

        do {
            XCTAssertEqual(actionCreator.$_setPlaceDiskCanceller.calledCount, 2)
            let placeDiskCanceller = try XCTUnwrap(actionCreator.$_setPlaceDiskCanceller.parameters.last)
            XCTAssertNil(placeDiskCanceller)
        }
    }

    func test_flippedDiskCoordinatesの返り値が空配列() throws {
        let placeDisk = dependency.testTarget
        let flippedDiskCoordinates = dependency.flippedDiskCoordinates

        let disk = Disk.dark
        let coordiate = Coordinate(x: 0, y: 0)
        let finshed = placeDisk(disk,
                                at: coordiate,
                                animated: false,
                                updateDisk: dependency.updateDisk)
            .asObservable()
        let result = Watcher(finshed)
        flippedDiskCoordinates._callAsFunction.onNext([])

        XCTAssertEqual(result.calledCount, 1)
        let error = try XCTUnwrap(result.errors.first as? PlaceDisk.Error)
        XCTAssertEqual(error, .diskPlacement(disk: disk, coordinate: coordiate))
    }
}

extension PlaceDiskTests {
    private final class Dependency {
        let testTarget: PlaceDisk

        let flippedDiskCoordinates = MockFlippedDiskCoordinates()
        let setDisk = MockSetDisk()
        let animateSettingDisks = MockAnimateSettingDisks()
        let actionCreator = MockGameActionCreator()
        let store = MockGameStore()
        let testScheduler = TestScheduler(initialClock: 0)
        let updateDisk = PublishRelay<UpdateDisk>()

        init() {
            self.testTarget = PlaceDisk(flippedDiskCoordinates: flippedDiskCoordinates,
                                        setDisk: setDisk,
                                        animateSettingDisks: animateSettingDisks,
                                        actionCreator: actionCreator,
                                        store: store,
                                        mainAsyncScheduler: testScheduler)
        }
    }
}
