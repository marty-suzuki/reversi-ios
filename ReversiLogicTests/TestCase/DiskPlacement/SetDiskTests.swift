import RxRelay
import XCTest
@testable import ReversiLogic

final class SetDiskTests: XCTestCase {
    private var dependency: Dependency!

    override func setUp() {
        self.dependency = Dependency()
    }

    func test_callAsFunction() throws {
        let disk = Disk.dark
        let coordinate = Coordinate(x: 0, y: 0)
        let animated = false
        let finished = true
        let actionCreator = dependency.actionCreator
        let _updateDisk = PublishRelay<UpdateDisk>()
        let updateDisk = Watcher(_updateDisk)

        let result = Watcher(dependency.testTarget(
            disk,
            at: coordinate,
            animated: animated,
            updateDisk: _updateDisk
        ).asObservable().share())

        let setDisk = actionCreator.$_setDisk
        XCTAssertEqual(setDisk.calledCount, 1)
        XCTAssertEqual(setDisk.parameters, [.init(disk: disk, coordinate: coordinate)])

        XCTAssertEqual(updateDisk.calledCount, 1)
        XCTAssertEqual(updateDisk.parameters, [.init(disk: disk, coordinate: coordinate, animated: animated, completion: nil)])
        let completion = try XCTUnwrap(updateDisk.parameters.first?.completion)
        completion(finished)

        XCTAssertEqual(result.calledCount, 1)
        XCTAssertEqual(result.parameters, [finished])
    }
}

extension SetDiskTests {
    private final class Dependency {
        let actionCreator = MockGameActionCreator()
        let testTarget: SetDisk

        init() {
            self.testTarget = SetDisk(actionCreator: actionCreator)
        }
    }
}
