import RxRelay
import TestModule
import XCTest
@testable import ReversiLogic

final class AnimateSettingDisksTests: XCTestCase {
    private var dependency: Dependency!

    override func setUp() {
        self.dependency = Dependency()
    }

    func test_coordinatesが空() {
        let animateSettingDisks = dependency.testTarget
        let updateDisk = dependency.updateDisk

        let result = animateSettingDisks(at: [],
                                         to: .dark,
                                         updateDisk: updateDisk)
        let watcher = Watcher(result.asObservable())

        XCTAssertEqual(watcher.calledCount, 1)
        XCTAssertEqual(watcher.parameters, [true])
    }

    func test_coordinatesが1件以上で_finshedがtrue() {
        let animateSettingDisks = dependency.testTarget
        let updateDisk = dependency.updateDisk
        let store = dependency.store
        let setDisk = dependency.setDisk

        let canceller = Canceller({})
        store.$placeDiskCanceller.accept(canceller)

        let coordinates = [Coordinate(x: 0, y: 0), Coordinate(x: 1, y: 0)]
        let result = animateSettingDisks(at: coordinates,
                                         to: .dark,
                                         updateDisk: updateDisk)
        let watcher = Watcher(result.asObservable())
        setDisk._callAsFunction.onNext(true)
        setDisk._callAsFunction.onNext(true)

        XCTAssertEqual(watcher.calledCount, 1)
        XCTAssertEqual(setDisk.$_callAsFunction.calledCount, 2)
        XCTAssertEqual(watcher.parameters, [true])
    }

    func test_coordinatesが1件以上で_finshedがfalse() {
        let animateSettingDisks = dependency.testTarget
        let updateDisk = dependency.updateDisk
        let store = dependency.store
        let setDisk = dependency.setDisk

        let canceller = Canceller({})
        store.$placeDiskCanceller.accept(canceller)

        let coordinates = [Coordinate(x: 0, y: 0), Coordinate(x: 1, y: 0)]
        let result = animateSettingDisks(at: coordinates,
                                         to: .dark,
                                         updateDisk: updateDisk)
        let watcher = Watcher(result.asObservable())
        setDisk._callAsFunction.onNext(false)
        setDisk._callAsFunction.onNext(false)

        XCTAssertEqual(watcher.calledCount, 1)
        XCTAssertEqual(setDisk.$_callAsFunction.calledCount, 3)
        XCTAssertEqual(watcher.parameters, [false])
    }

    func test_storeのplaceDiskCancellerがcancelされている() throws {
        let animateSettingDisks = dependency.testTarget
        let updateDisk = dependency.updateDisk
        let store = dependency.store
        let setDisk = dependency.setDisk

        let canceller = Canceller({})
        canceller.cancel()
        store.$placeDiskCanceller.accept(canceller)

        let coordinates = [Coordinate(x: 0, y: 0)]
        let result = animateSettingDisks(at: coordinates,
                                         to: .dark,
                                         updateDisk: updateDisk)
        let watcher = Watcher(result.asObservable())
        setDisk._callAsFunction.onNext(true)

        XCTAssertEqual(watcher.calledCount, 1)
        XCTAssertEqual(watcher.errors.count, 1)
        XCTAssertTrue(watcher.parameters.isEmpty)
        let error = try XCTUnwrap(watcher.errors.last as? AnimateSettingDisks.Error)
        XCTAssertEqual(error, .animationCancellerCancelled)
    }

    func test_storeのplaceDiskCancellerがnil() throws {
        let animateSettingDisks = dependency.testTarget
        let updateDisk = dependency.updateDisk
        let store = dependency.store
        store.$placeDiskCanceller.accept(nil)


        let coordinates = [Coordinate(x: 0, y: 0)]
        let result = animateSettingDisks(at: coordinates,
                                         to: .dark,
                                         updateDisk: updateDisk)
        let watcher = Watcher(result.asObservable())

        XCTAssertEqual(watcher.calledCount, 1)
        XCTAssertEqual(watcher.errors.count, 1)
        XCTAssertTrue(watcher.parameters.isEmpty)
        let error = try XCTUnwrap(watcher.errors.last as? AnimateSettingDisks.Error)
        XCTAssertEqual(error, .animationCancellerReleased)
    }
}

extension AnimateSettingDisksTests {
    private final class Dependency {
        let testTarget: AnimateSettingDisks

        let setDisk = MockSetDisk()
        let store = MockGameStore()
        let updateDisk = PublishRelay<UpdateDisk>()

        init() {
            self.testTarget = AnimateSettingDisks(setDisk: setDisk
                , store: store)
        }
    }
}
