import RxRelay
import RxSwift
import RxTest
import XCTest
@testable import ReversiLogic

final class ReversiViewModelTests: XCTestCase {

    private var dependency: Dependency!

    override func setUp() {
        self.dependency = Dependency(messageDiskSize: 0)
    }

    func test_viewDidAppear_waitForPlayerが2回呼ばれることはない() {
        let viewModel = dependency.testTarget
        let managementStream = dependency.managementStream

        let watcher = Watcher(managementStream._input.waitForPlayer)

        viewModel.input.viewDidAppear(())
        XCTAssertEqual(watcher.calledCount, 1)

        viewModel.input.viewDidAppear(())
        XCTAssertEqual(watcher.calledCount, 1)
    }

    func test_status_gameOverじゃない場合() {
        let expectedSize = CGFloat(arc4random() % 100)
        self.dependency = Dependency(messageDiskSize: expectedSize)
        let managementStream = dependency.managementStream
        let viewModel = dependency.testTarget

        let messageDiskSizeConstant = Watcher(viewModel.output.messageDiskSizeConstant)
        let messageDisk = Watcher(viewModel.output.messageDisk)
        let mwssageText = Watcher(viewModel.output.messageText)

        let expectedTurn = Disk.light
        managementStream.$status.accept(.turn(expectedTurn))

        XCTAssertEqual(messageDiskSizeConstant.calledCount, 1)
        XCTAssertEqual(messageDiskSizeConstant.parameters, [expectedSize])

        XCTAssertEqual(messageDisk.calledCount, 1)
        XCTAssertEqual(messageDisk.parameters, [expectedTurn])

        XCTAssertEqual(mwssageText.calledCount, 1)
        XCTAssertEqual(mwssageText.parameters, ["'s turn"])
    }

    func test_status_gameOverで勝者がいる場合() {
        let expectedDisk = Disk.dark
        let expectedSize = CGFloat(arc4random() % 100)
        self.dependency = Dependency(messageDiskSize: expectedSize)
        let managementStream = dependency.managementStream
        let viewModel = dependency.testTarget

        let messageDiskSizeConstant = Watcher(viewModel.output.messageDiskSizeConstant)
        let messageDisk = Watcher(viewModel.output.messageDisk)
        let mwssageText = Watcher(viewModel.output.messageText)

        managementStream.$sideWithMoreDisks.accept(expectedDisk)
        managementStream.$status.accept(.gameOver)

        XCTAssertEqual(messageDiskSizeConstant.calledCount, 1)
        XCTAssertEqual(messageDiskSizeConstant.parameters, [expectedSize])

        XCTAssertEqual(messageDisk.calledCount, 1)
        XCTAssertEqual(messageDisk.parameters, [expectedDisk])

        XCTAssertEqual(mwssageText.calledCount, 1)
        XCTAssertEqual(mwssageText.parameters, [" won"])
    }

    func test_status_gameOverで勝者がいない場合() {
        let managementStream = dependency.managementStream
        let viewModel = dependency.testTarget
        self.dependency = Dependency(messageDiskSize: 0)

        let messageDiskSizeConstant = Watcher(viewModel.output.messageDiskSizeConstant)
        let messageDisk = Watcher(viewModel.output.messageDisk)
        let mwssageText = Watcher(viewModel.output.messageText)

        managementStream.$sideWithMoreDisks.accept(nil)
        managementStream.$status.accept(.gameOver)

        XCTAssertEqual(messageDiskSizeConstant.calledCount, 1)
        XCTAssertEqual(messageDiskSizeConstant.parameters, [0])

        XCTAssertEqual(messageDisk.calledCount, 0)

        XCTAssertEqual(mwssageText.calledCount, 1)
        XCTAssertEqual(mwssageText.parameters, ["Tied"])
    }

    func test_updateCount() {
        let darkCount = Int(arc4random() % 100)
        let lightCount = Int(arc4random() % 100)
        let managementStream = dependency.managementStream
        let viewModel = dependency.testTarget

        managementStream.$countOfDark.accept(darkCount)
        managementStream.$countOfLight.accept(lightCount)

        let playerDarkCount = Watcher(viewModel.output.playerDarkCount)
        let playerLightCount = Watcher(viewModel.output.playerLightCount)

        dependency.state.updateCount.accept(())

        XCTAssertEqual(playerDarkCount.calledCount, 1)
        XCTAssertEqual(playerDarkCount.parameters, ["\(darkCount)"])

        XCTAssertEqual(playerLightCount.calledCount, 1)
        XCTAssertEqual(playerLightCount.parameters, ["\(lightCount)"])
    }

    func test_isPlayerDarkAnimating_and_isPlayerLightAnimating() {
        let managementStream = dependency.managementStream
        let viewModel = dependency.testTarget

        let isPlayerDarkAnimating = Watcher(viewModel.output.isPlayerDarkAnimating)
        let isPlayerLightAnimating = Watcher(viewModel.output.isPlayerLightAnimating)

        managementStream.$willTurnDiskOfComputer.accept(.dark)

        XCTAssertEqual(isPlayerDarkAnimating.calledCount, 1)
        XCTAssertEqual(isPlayerDarkAnimating.parameters, [true])
        XCTAssertEqual(isPlayerLightAnimating.calledCount, 0)

        managementStream.$didTurnDiskOfComputer.accept(.light)

        XCTAssertEqual(isPlayerDarkAnimating.calledCount, 1)
        XCTAssertEqual(isPlayerDarkAnimating.parameters, [true])
        XCTAssertEqual(isPlayerLightAnimating.calledCount, 1)
        XCTAssertEqual(isPlayerLightAnimating.parameters, [false])
    }
}

extension ReversiViewModelTests {

    fileprivate final class Dependency {

        let state = ReversiViewModel.State()
        let testScheduler = TestScheduler(initialClock: 0)
        let placeDiskStream = MockReversiPlaceDiskStream()
        let managementStream = MockReversiManagementStream()
        private(set) lazy var extra = ReversiViewModel.Extra(
            messageDiskSize: messageDiskSize,
            mainAsyncScheduler: testScheduler,
            mainScheduler: testScheduler,
            placeDiskStream: placeDiskStream,
            managementStream: managementStream
        )

        private let messageDiskSize: CGFloat
        private let disposeBag = DisposeBag()

        private(set) lazy var testTarget = ReversiViewModel(
            input: ReversiViewModel.Input(),
            state: state,
            extra: extra
        )

        init(messageDiskSize: CGFloat) {
            self.messageDiskSize = messageDiskSize
        }
    }
}
