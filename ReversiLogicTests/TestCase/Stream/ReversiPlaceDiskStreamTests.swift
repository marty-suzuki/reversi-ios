import RxTest
import XCTest
@testable import ReversiLogic

final class ReversiPlaceDiskStreamTests: XCTestCase {

    private var dependency: Dependency!

    override func setUp() {
        self.dependency = Dependency()
    }

    func test_handleDiskWithCoordinate() {
        let coordinate = Coordinate(x: 0, y: 0)

        dependency.testTarget.input.handleDiskWithCoordinate((.dark, coordinate))
    }
}

extension ReversiPlaceDiskStreamTests {

    private final class  Dependency {

        let store = MockGameStore()
        let actionCreator = MockGameActionCreator()
        let flippedDiskCoordinates = MockFlippedDiskCoordinates()
        let testScheduler = TestScheduler(initialClock: 0)

        let testTarget: ReversiPlaceDiskStream

        init() {
            self.testTarget = ReversiPlaceDiskStream(
                actionCreator: actionCreator,
                store: store,
                mainAsyncScheduler: testScheduler,
                flippedDiskCoordinates: flippedDiskCoordinates
            )
        }
    }
}
